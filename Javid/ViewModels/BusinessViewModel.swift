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
    private let pageSize = 20
    
    // Location properties for "Near Me" feature
    @Published var sortByDistance = false
    var userLocation: CLLocation?
    
    init() {
        fetchBusinesses()
    }
    
    // Fetch first page
    func fetchBusinesses() {
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
                
                self?.lastDocument = documents.last
                self?.hasMoreData = documents.count == self?.pageSize
                
                print("âœ… Loaded \(self?.businesses.count ?? 0) businesses")
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
                self?.lastDocument = documents.last
                self?.hasMoreData = documents.count == self?.pageSize
                
                print("âœ… Loaded \(newBusinesses.count) more businesses. Total: \(self?.businesses.count ?? 0)")
            }
    }
    
    // Refresh (pull to refresh)
    func refreshBusinesses() {
        businesses = []
        lastDocument = nil
        hasMoreData = true
        fetchBusinesses()
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
                    // Add to local list
                    self.businesses.insert(newBusiness, at: 0)
                    completion(true, "âœ… Business added successfully!")
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
                    // Update local list
                    if let index = self.businesses.firstIndex(where: { $0.id == businessId }) {
                        self.businesses[index] = business
                    }
                    completion(true, "âœ… Business updated successfully!")
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
                    // Remove from local list
                    self.businesses.removeAll { $0.id == businessId }
                    completion(true, "âœ… Business deleted successfully!")
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
        CloudinaryManager.shared.uploadImage(image) { result in
            switch result {
            case .success(let url):
                print("âœ… Image uploaded: \(url)")
                completion(url)
            case .failure(let error):
                print("âŒ Upload failed: \(error.localizedDescription)")
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
