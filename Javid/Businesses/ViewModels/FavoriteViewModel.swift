import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class FavoriteViewModel: ObservableObject {
    @Published var favorites: [Favorite] = []
    @Published var favoriteBusinessIds: Set<String> = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var favoritesListener: ListenerRegistration?
    
    init() {
        fetchUserFavorites()
    }
    
    deinit {
        favoritesListener?.remove()
    }
    
    // Fetch user's favorites with real-time updates
    func fetchUserFavorites() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            return
        }
        
        isLoading = true
        
        // Remove previous listener
        favoritesListener?.remove()
        
        // Add real-time listener
        favoritesListener = db.collection("favorites")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    print("Error fetching favorites: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No favorites found")
                    return
                }
                
                self?.favorites = documents.compactMap { doc -> Favorite? in
                    try? doc.data(as: Favorite.self)
                }
                
                // Create Set for fast lookup
                self?.favoriteBusinessIds = Set(self?.favorites.map { $0.businessId } ?? [])
                
                print("Loaded \(self?.favorites.count ?? 0) favorites")
            }
    }
    
    // Check if business is favorited
    func isFavorite(businessId: String) -> Bool {
        return favoriteBusinessIds.contains(businessId)
    }
    
    // Add to favorites
    func addFavorite(businessId: String, completion: @escaping (Bool, String) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false, "Please login to save favorites")
            return
        }
        
        print("Adding business \(businessId) to favorites...")
        
        let favorite = Favorite(userId: userId, businessId: businessId)
        
        do {
            try db.collection("favorites").addDocument(from: favorite) { error in
                if let error = error {
                    print("Error adding favorite: \(error)")
                    completion(false, "Failed to save favorite")
                } else {
                    print("Added to favorites")
                    completion(true, "Added to favorites")
                }
            }
        } catch {
            print("Error encoding favorite: \(error)")
            completion(false, "Failed to save favorite")
        }
    }
    
    // Remove from favorites
    func removeFavorite(businessId: String, completion: @escaping (Bool, String) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false, "User not logged in")
            return
        }
        
        print("Removing business \(businessId) from favorites...")
        
        db.collection("favorites")
            .whereField("userId", isEqualTo: userId)
            .whereField("businessId", isEqualTo: businessId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error finding favorite: \(error)")
                    completion(false, "Failed to remove favorite")
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    print("Favorite not found")
                    completion(false, "Favorite not found")
                    return
                }
                
                self?.db.collection("favorites").document(document.documentID).delete { error in
                    if let error = error {
                        print("Error removing favorite: \(error)")
                        completion(false, "Failed to remove favorite")
                    } else {
                        print("Removed from favorites")
                        completion(true, "Removed from favorites")
                    }
                }
            }
    }
    
    // Toggle favorite (add or remove)
    func toggleFavorite(businessId: String, completion: @escaping (Bool, String) -> Void) {
        if isFavorite(businessId: businessId) {
            removeFavorite(businessId: businessId, completion: completion)
        } else {
            addFavorite(businessId: businessId, completion: completion)
        }
    }
    
    // Get list of favorite businesses
    func getFavoriteBusinesses(from allBusinesses: [Business]) -> [Business] {
        return allBusinesses.filter { business in
            guard let businessId = business.id else { return false }
            return favoriteBusinessIds.contains(businessId)
        }
    }
}
