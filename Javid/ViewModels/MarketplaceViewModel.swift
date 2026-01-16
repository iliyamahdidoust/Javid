import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
import Combine
import UIKit

class MarketplaceViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var items: [MarketplaceItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage = ""
    @Published var hasMoreData = true
    @Published var savedItemIds: Set<String> = []
    
    // Filter properties
    @Published var selectedCategory: MarketplaceCategory? = nil
    @Published var selectedCondition: ItemCondition? = nil
    @Published var priceRange: ClosedRange<Double> = 0...10000
    @Published var sortByDistance = false
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var lastDocument: DocumentSnapshot?
    private let pageSize = 15
    private var itemsListener: ListenerRegistration?
    private var savesListener: ListenerRegistration?
    
    // Location for distance sorting
    var userLocation: CLLocation?
    
    // Cache
    private var itemsCache: [MarketplaceItem] = []
    private var cacheTimestamp: Date?
    private let cacheValidDuration: TimeInterval = 300 // 5 minutes
    
    // Track viewed items to prevent duplicate view counts
    private var viewedItemIds: Set<String> = []
    
    // MARK: - Initialization
    init() {
        loadViewedItems() // Load viewed items first
        setupRealtimeListener()
        fetchUserSavedItems()
    }
    
    deinit {
        itemsListener?.remove()
        savesListener?.remove()
        saveViewedItems() // Save viewed items when deinit
    }
    
    // MARK: - Load/Save Viewed Items (Persistent across app launches)
    
    private func loadViewedItems() {
        if let data = UserDefaults.standard.data(forKey: "viewedMarketplaceItems"),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            viewedItemIds = decoded
            print("✅ Loaded \(viewedItemIds.count) previously viewed items")
        }
    }
    
    private func saveViewedItems() {
        if let encoded = try? JSONEncoder().encode(viewedItemIds) {
            UserDefaults.standard.set(encoded, forKey: "viewedMarketplaceItems")
            print("💾 Saved \(viewedItemIds.count) viewed items to UserDefaults")
        }
    }
    
    // MARK: - Increment View Count (Only Once Per User)
    
    func incrementViewCount(for itemId: String) {
        // Check if already viewed by this user
        guard !viewedItemIds.contains(itemId) else {
            print("👁️ Item \(itemId) already viewed by this user, skipping increment")
            return
        }
        
        // Mark as viewed
        viewedItemIds.insert(itemId)
        saveViewedItems()
        
        print("👁️ First time viewing item \(itemId), incrementing view count")
        
        // Increment in Firestore
        db.collection("marketplace_items").document(itemId).updateData([
            "viewCount": FieldValue.increment(Int64(1))
        ]) { error in
            if let error = error {
                print("❌ Error incrementing view count: \(error.localizedDescription)")
            } else {
                print("✅ View count incremented for item: \(itemId)")
            }
        }
    }
    
    // MARK: - Clear Viewed Items (Optional - for testing or reset)
    
    func clearViewedItems() {
        viewedItemIds.removeAll()
        saveViewedItems()
        print("🗑️ Cleared all viewed items")
    }
    
    // MARK: - Real-time Listener
    private func setupRealtimeListener() {
        guard !isLoading else { return }
        
        isLoading = true
        
        var query: Query = db.collection("marketplace_items")
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)
        
        // Apply filters
        if let category = selectedCategory {
            query = query.whereField("category", isEqualTo: category.rawValue)
        }
        
        itemsListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = "Failed to load items: \(error.localizedDescription)"
                print("❌ Error fetching marketplace items: \(error)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No marketplace items found")
                self.hasMoreData = false
                return
            }
            
            // Update only changes, not everything
            snapshot?.documentChanges.forEach { change in
                if let item = try? change.document.data(as: MarketplaceItem.self) {
                    switch change.type {
                    case .added:
                        if !self.items.contains(where: { $0.id == item.id }) {
                            self.items.append(item)
                        }
                    case .modified:
                        if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                            self.items[index] = item
                        }
                    case .removed:
                        self.items.removeAll { $0.id == item.id }
                    }
                }
            }
            
            self.lastDocument = documents.last
            self.hasMoreData = documents.count == self.pageSize
            
            // Sort items
            self.sortItems()
            
            print("✅ Loaded \(self.items.count) marketplace items")
        }
    }
    
    // MARK: - Fetch Items (fallback)
    func fetchItems() {
        // Check cache first
        if let cacheTimestamp = cacheTimestamp,
           Date().timeIntervalSince(cacheTimestamp) < cacheValidDuration,
           !itemsCache.isEmpty {
            self.items = itemsCache
            print("✅ Loaded from cache: \(items.count) items")
            return
        }
        
        guard !isLoading else { return }
        
        isLoading = true
        lastDocument = nil
        
        var query: Query = db.collection("marketplace_items")
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)
        
        // Apply category filter
        if let category = selectedCategory {
            query = query.whereField("category", isEqualTo: category.rawValue)
        }
        
        query.getDocuments { [weak self] snapshot, error in
            self?.isLoading = false
            
            if let error = error {
                self?.errorMessage = "Failed to load items: \(error.localizedDescription)"
                print("❌ Error fetching items: \(error)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No items found")
                self?.hasMoreData = false
                return
            }
            
            self?.items = documents.compactMap { doc -> MarketplaceItem? in
                try? doc.data(as: MarketplaceItem.self)
            }
            
            // Update cache
            self?.itemsCache = self?.items ?? []
            self?.cacheTimestamp = Date()
            
            self?.lastDocument = documents.last
            self?.hasMoreData = documents.count == self?.pageSize
            
            // Sort items
            self?.sortItems()
            
            print("✅ Loaded \(self?.items.count ?? 0) marketplace items")
        }
    }
    
    // MARK: - Load More (Pagination)
    func loadMoreItems() {
        guard !isLoadingMore,
              !isLoading,
              hasMoreData,
              let lastDoc = lastDocument else {
            return
        }
        
        isLoadingMore = true
        
        var query: Query = db.collection("marketplace_items")
            .order(by: "createdAt", descending: true)
            .start(afterDocument: lastDoc)
            .limit(to: pageSize)
        
        if let category = selectedCategory {
            query = query.whereField("category", isEqualTo: category.rawValue)
        }
        
        query.getDocuments { [weak self] snapshot, error in
            self?.isLoadingMore = false
            
            if let error = error {
                print("❌ Error loading more: \(error)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                self?.hasMoreData = false
                return
            }
            
            let newItems = documents.compactMap { doc -> MarketplaceItem? in
                try? doc.data(as: MarketplaceItem.self)
            }
            
            self?.items.append(contentsOf: newItems)
            
            // Update cache
            self?.itemsCache = self?.items ?? []
            self?.cacheTimestamp = Date()
            
            self?.lastDocument = documents.last
            self?.hasMoreData = documents.count == self?.pageSize
            
            // Sort items
            self?.sortItems()
            
            print("✅ Loaded \(newItems.count) more items. Total: \(self?.items.count ?? 0)")
        }
    }
    
    // MARK: - Refresh
    func refreshItems() {
        // Clear cache
        itemsCache = []
        cacheTimestamp = nil
        
        items = []
        lastDocument = nil
        hasMoreData = true
        
        // Remove old listener
        itemsListener?.remove()
        
        // Setup new listener
        setupRealtimeListener()
    }
    
    // MARK: - Add Item
    func addItem(_ item: MarketplaceItem, completion: @escaping (Bool, String) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false, "You must be logged in to list an item")
            return
        }
        
        var newItem = item
        newItem.sellerId = userId
        
        do {
            try db.collection("marketplace_items").document(item.id ?? UUID().uuidString).setData(from: newItem) { error in
                if let error = error {
                    completion(false, "Failed to add item: \(error.localizedDescription)")
                } else {
                    completion(true, "✅ Item listed successfully!")
                }
            }
        } catch {
            completion(false, "Failed to encode item data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Update Item
    func updateItem(_ item: MarketplaceItem, completion: @escaping (Bool, String) -> Void) {
        guard let itemId = item.id else {
            completion(false, "Invalid item ID")
            return
        }
        
        do {
            try db.collection("marketplace_items").document(itemId).setData(from: item) { error in
                if let error = error {
                    completion(false, "Failed to update item: \(error.localizedDescription)")
                } else {
                    completion(true, "✅ Item updated successfully!")
                }
            }
        } catch {
            completion(false, "Failed to encode item data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Delete Item
    func deleteItem(_ item: MarketplaceItem, completion: @escaping (Bool, String) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false, "You must be logged in")
            return
        }
        
        guard let itemId = item.id else {
            completion(false, "Invalid item ID")
            return
        }
        
        guard item.sellerId == userId else {
            completion(false, "You can only delete your own items")
            return
        }
        
        // Delete images first
        let group = DispatchGroup()
        for photoURL in item.photoURLs {
            group.enter()
            CloudinaryManager.shared.deleteImage(url: photoURL) { _ in
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.db.collection("marketplace_items").document(itemId).delete { error in
                if let error = error {
                    completion(false, "Failed to delete item: \(error.localizedDescription)")
                } else {
                    completion(true, "✅ Item deleted successfully!")
                }
            }
        }
    }
    
    // MARK: - Mark as Sold
    func markAsSold(_ item: MarketplaceItem, completion: @escaping (Bool, String) -> Void) {
        guard let itemId = item.id else {
            completion(false, "Invalid item ID")
            return
        }
        
        db.collection("marketplace_items").document(itemId).updateData([
            "isSold": true
        ]) { error in
            if let error = error {
                completion(false, "Failed to mark as sold: \(error.localizedDescription)")
            } else {
                completion(true, "✅ Marked as sold!")
            }
        }
    }
    
    // MARK: - Upload Image
    func uploadImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
        CloudinaryManager.shared.uploadImage(image, folder: .marketplace, preset: .marketplace) { result in
            switch result {
            case .success(let url):
                print("✅ Image uploaded: \(url)")
                completion(url)
            case .failure(let error):
                print("❌ Upload failed: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    // MARK: - Get User Items
    func getUserItems() -> [MarketplaceItem] {
        guard let userId = Auth.auth().currentUser?.uid else {
            return []
        }
        return items.filter { $0.sellerId == userId }
    }
    
    // MARK: - Saved Items
    func fetchUserSavedItems() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            return
        }
        
        // Remove previous listener
        savesListener?.remove()
        
        // Add real-time listener for saved items
        savesListener = db.collection("marketplace_saves")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error fetching saved items: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No saved items found")
                    return
                }
                
                let saves = documents.compactMap { doc -> MarketplaceSave? in
                    try? doc.data(as: MarketplaceSave.self)
                }
                
                // Create Set for fast lookup
                self?.savedItemIds = Set(saves.map { $0.itemId })
                
                print("✅ Loaded \(saves.count) saved items")
            }
    }
    
    // MARK: - Check if Item is Saved
    func isSaved(itemId: String) -> Bool {
        return savedItemIds.contains(itemId)
    }
    
    // MARK: - Save Item
    func saveItem(itemId: String, completion: @escaping (Bool, String) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false, "Please login to save items")
            return
        }
        
        print("💾 Saving item: \(itemId)")
        
        let save = MarketplaceSave(userId: userId, itemId: itemId)
        
        do {
            try db.collection("marketplace_saves").addDocument(from: save) { error in
                if let error = error {
                    print("❌ Error saving item: \(error)")
                    completion(false, "Failed to save item")
                } else {
                    // Increment saved count
                    self.db.collection("marketplace_items").document(itemId).updateData([
                        "savedCount": FieldValue.increment(Int64(1))
                    ])
                    print("✅ Item saved")
                    completion(true, "Item saved")
                }
            }
        } catch {
            print("❌ Error encoding save: \(error)")
            completion(false, "Failed to save item")
        }
    }
    
    // MARK: - Unsave Item
    func unsaveItem(itemId: String, completion: @escaping (Bool, String) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false, "User not logged in")
            return
        }
        
        print("🗑️ Removing saved item: \(itemId)")
        
        db.collection("marketplace_saves")
            .whereField("userId", isEqualTo: userId)
            .whereField("itemId", isEqualTo: itemId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error finding saved item: \(error)")
                    completion(false, "Failed to remove saved item")
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    print("❌ Saved item not found")
                    completion(false, "Saved item not found")
                    return
                }
                
                self?.db.collection("marketplace_saves").document(document.documentID).delete { error in
                    if let error = error {
                        print("❌ Error removing saved item: \(error)")
                        completion(false, "Failed to remove saved item")
                    } else {
                        // Decrement saved count
                        self?.db.collection("marketplace_items").document(itemId).updateData([
                            "savedCount": FieldValue.increment(Int64(-1))
                        ])
                        print("✅ Saved item removed")
                        completion(true, "Saved item removed")
                    }
                }
            }
    }
    
    // MARK: - Toggle Save
    func toggleSave(itemId: String, completion: @escaping (Bool, String) -> Void) {
        if isSaved(itemId: itemId) {
            unsaveItem(itemId: itemId, completion: completion)
        } else {
            saveItem(itemId: itemId, completion: completion)
        }
    }
    
    // MARK: - Get Saved Items
    func getSavedItems() -> [MarketplaceItem] {
        return items.filter { item in
            guard let itemId = item.id else { return false }
            return savedItemIds.contains(itemId)
        }
    }
    
    // MARK: - Search Items
    func searchItems(query: String) -> [MarketplaceItem] {
        guard !query.isEmpty else { return items }
        
        let lowercasedQuery = query.lowercased()
        
        return items.filter { item in
            item.title.lowercased().contains(lowercasedQuery) ||
            item.description.lowercased().contains(lowercasedQuery) ||
            item.location.lowercased().contains(lowercasedQuery) ||
            item.category.rawValue.lowercased().contains(lowercasedQuery)
        }
    }
    
    // MARK: - Filter Items
    func filterItems() -> [MarketplaceItem] {
        var filtered = items
        
        // Filter by category
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        // Filter by condition
        if let condition = selectedCondition {
            filtered = filtered.filter { $0.condition == condition }
        }
        
        // Filter by price range
        filtered = filtered.filter { $0.price >= priceRange.lowerBound && $0.price <= priceRange.upperBound }
        
        // Filter out sold items (optional)
        // filtered = filtered.filter { !$0.isSold }
        
        return filtered
    }
    
    // MARK: - Sort Items
    private func sortItems() {
        if sortByDistance, let userLocation = userLocation {
            items.sort { item1, item2 in
                let distance1 = userLocation.distance(from: CLLocation(
                    latitude: item1.latitude,
                    longitude: item1.longitude
                ))
                let distance2 = userLocation.distance(from: CLLocation(
                    latitude: item2.latitude,
                    longitude: item2.longitude
                ))
                return distance1 < distance2
            }
        }
    }
    
    // MARK: - Sort by Distance
    func sortItemsByDistance(userLocation: CLLocation) {
        self.userLocation = userLocation
        sortByDistance = true
        sortItems()
    }
    
    // MARK: - Get Distance
    func getDistance(to item: MarketplaceItem) -> Double? {
        guard let userLocation = userLocation else { return nil }
        
        let itemLocation = CLLocation(
            latitude: item.latitude,
            longitude: item.longitude
        )
        
        // Convert meters to kilometers
        return userLocation.distance(from: itemLocation) / 1000
    }
}
