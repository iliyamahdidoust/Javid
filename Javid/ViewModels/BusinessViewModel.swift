import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
import Combine

class BusinessViewModel: ObservableObject {
    @Published var businesses: [Business] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage = ""
    @Published var hasMoreData = true
    
    private let db = Firestore.firestore()
    private var lastDocument: DocumentSnapshot?
    private let pageSize = 5  // REDUCED from 10 for better performance
    
    // Location properties for "Near Me" feature
    @Published var sortByDistance = false
    var userLocation: CLLocation?
    
    // Cache
    private var businessesCache: [Business] = []
    private var cacheTimestamp: Date?
    private let cacheValidDuration: TimeInterval = 300 // 5 minutes
    
    // Listener
    private var businessesListener: ListenerRegistration?
    
    init() {
        setupRealtimeListener()
    }
    
    deinit {
        businessesListener?.remove()
    }
    
    // Real-time listener for better performance
    private func setupRealtimeListener() {
        guard !isLoading else { return }
        
        isLoading = true
        
        businessesListener = db.collection("businesses")
            .order(by: "name")
            .limit(to: pageSize)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let error = error {
                    print("❌ Firebase Error: \(error.localizedDescription)")
                    self.errorMessage = "Failed to load businesses: \(error.localizedDescription)"
                    
                    // Don't crash - handle gracefully
                    self.businesses = []
                    self.hasMoreData = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No businesses found")
                    self.hasMoreData = false
                    return
                }
                
                // Update only changes, not everything
                snapshot?.documentChanges.forEach { change in
                    do {
                        let business = try change.document.data(as: Business.self)
                        switch change.type {
                        case .added:
                            if !self.businesses.contains(where: { $0.id == business.id }) {
                                self.businesses.append(business)
                            }
                        case .modified:
                            if let index = self.businesses.firstIndex(where: { $0.id == business.id }) {
                                self.businesses[index] = business
                            }
                        case .removed:
                            self.businesses.removeAll { $0.id == business.id }
                        }
                    } catch {
                        print("❌ Error decoding business: \(error)")
                    }
                }
                
                self.lastDocument = documents.last
                self.hasMoreData = documents.count == self.pageSize
                
                // Sort by name
                self.businesses.sort { $0.name < $1.name }
                
                print("✅ Loaded \(self.businesses.count) businesses")
            }
    }
    
    // Fetch first page (fallback if listener doesn't work)
    func fetchBusinesses() {
        // Check cache first
        if let cacheTimestamp = cacheTimestamp,
           Date().timeIntervalSince(cacheTimestamp) < cacheValidDuration,
           !businessesCache.isEmpty {
            self.businesses = businessesCache
            print("✅ Loaded from cache: \(businesses.count) businesses")
            return
        }
        
        guard !isLoading else { return }
        
        isLoading = true
        lastDocument = nil
        
        db.collection("businesses")
            .order(by: "name")
            .limit(to: pageSize)
            .getDocuments { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Failed to load businesses: \(error.localizedDescription)"
                    print("Error fetching businesses: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No businesses found")
                    self?.hasMoreData = false
                    return
                }
                
                self?.businesses = documents.compactMap { doc -> Business? in
                    try? doc.data(as: Business.self)
                }
                
                // Update cache
                self?.businessesCache = self?.businesses ?? []
                self?.cacheTimestamp = Date()
                
                self?.lastDocument = documents.last
                self?.hasMoreData = documents.count == self?.pageSize
                
                print("✅ Loaded \(self?.businesses.count ?? 0) businesses")
            }
    }
    
    // Load more (pagination)
    func loadMoreBusinesses() {
        guard !isLoadingMore,
              !isLoading,
              hasMoreData,
              let lastDoc = lastDocument else {
            return
        }
        
        isLoadingMore = true
        
        db.collection("businesses")
            .order(by: "name")
            .start(afterDocument: lastDoc)
            .limit(to: pageSize)
            .getDocuments { [weak self] snapshot, error in
                self?.isLoadingMore = false
                
                if let error = error {
                    print("Error loading more: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self?.hasMoreData = false
                    return
                }
                
                let newBusinesses = documents.compactMap { doc -> Business? in
                    try? doc.data(as: Business.self)
                }
                
                self?.businesses.append(contentsOf: newBusinesses)
                
                // Update cache
                self?.businessesCache = self?.businesses ?? []
                self?.cacheTimestamp = Date()
                
                self?.lastDocument = documents.last
                self?.hasMoreData = documents.count == self?.pageSize
                
                print("✅ Loaded \(newBusinesses.count) more businesses. Total: \(self?.businesses.count ?? 0)")
            }
    }
    
    // Refresh (pull to refresh)
    func refreshBusinesses() {
        // Clear cache
        businessesCache = []
        cacheTimestamp = nil
        
        businesses = []
        lastDocument = nil
        hasMoreData = true
        
        // Remove old listener
        businessesListener?.remove()
        
        // Setup new listener
        setupRealtimeListener()
    }
    
    // Add a new business to Firestore
    func addBusiness(_ business: Business, completion: @escaping (Bool, String) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false, "You must be logged in to add a business")
            return
        }
        
        var newBusiness = business
        newBusiness.ownerId = userId
        
        do {
            try db.collection("businesses").document(business.id ?? UUID().uuidString).setData(from: newBusiness) { error in
                if let error = error {
                    completion(false, "Failed to add business: \(error.localizedDescription)")
                } else {
                    // Listener will automatically update the list
                    completion(true, "✅ Business added successfully!")
                }
            }
        } catch {
            completion(false, "Failed to encode business data: \(error.localizedDescription)")
        }
    }
    
    // Update an existing business
    func updateBusiness(_ business: Business, completion: @escaping (Bool, String) -> Void) {
        guard let businessId = business.id else {
            completion(false, "Invalid business ID")
            return
        }
        
        do {
            try db.collection("businesses").document(businessId).setData(from: business) { error in
                if let error = error {
                    completion(false, "Failed to update business: \(error.localizedDescription)")
                } else {
                    // Listener will automatically update the list
                    completion(true, "✅ Business updated successfully!")
                }
            }
        } catch {
            completion(false, "Failed to encode business data: \(error.localizedDescription)")
        }
    }
    
    // Delete a business
    func deleteBusiness(_ business: Business, completion: @escaping (Bool, String) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false, "You must be logged in")
            return
        }
        
        guard let businessId = business.id else {
            completion(false, "Invalid business ID")
            return
        }
        
        guard business.ownerId == userId else {
            completion(false, "You can only delete your own businesses")
            return
        }
        
        // Delete images first
        let group = DispatchGroup()
        for photoURL in business.photoURLs {
            group.enter()
            deleteImage(url: photoURL) { _ in
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.db.collection("businesses").document(businessId).delete { error in
                if let error = error {
                    completion(false, "Failed to delete business: \(error.localizedDescription)")
                } else {
                    // Listener will automatically update the list
                    completion(true, "✅ Business deleted successfully!")
                }
            }
        }
    }
    
    // Get businesses owned by current user
    func getUserBusinesses() -> [Business] {
        guard let userId = Auth.auth().currentUser?.uid else {
            return []
        }
        return businesses.filter { $0.ownerId == userId }
    }
    
    // Upload image using Cloudinary
    func uploadImage(_ image: UIImage, for businessId: String, completion: @escaping (String?) -> Void) {
        CloudinaryManager.shared.uploadImage(image, folder: .business, preset: .business) { result in
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
    
    // Delete image using Cloudinary
    func deleteImage(url: String, completion: @escaping (Bool) -> Void) {
        CloudinaryManager.shared.deleteImage(url: url, completion: completion)
    }
    
    // Sort businesses by distance from user location
    func sortBusinessesByDistance(userLocation: CLLocation) {
        self.userLocation = userLocation
        
        // Sort the businesses array by distance (closest first)
        businesses.sort { business1, business2 in
            let distance1 = userLocation.distance(from: CLLocation(
                latitude: business1.latitude,
                longitude: business1.longitude
            ))
            let distance2 = userLocation.distance(from: CLLocation(
                latitude: business2.latitude,
                longitude: business2.longitude
            ))
            return distance1 < distance2
        }
    }

    // Get distance from user to a specific business (in kilometers)
    func getDistance(to business: Business) -> Double? {
        guard let userLocation = userLocation else { return nil }
        
        let businessLocation = CLLocation(
            latitude: business.latitude,
            longitude: business.longitude
        )
        
        // Convert meters to kilometers
        return userLocation.distance(from: businessLocation) / 1000
    }
}
