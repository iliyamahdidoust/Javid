import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class ReviewViewModel: ObservableObject {
    @Published var reviews: [Review] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let db = Firestore.firestore()
    private var reviewsListener: ListenerRegistration?
    
    deinit {
        reviewsListener?.remove()
    }
    
    // Fetch reviews for a specific business with real-time listener
    func fetchReviews(for businessId: String) {
        // Remove old listener
        reviewsListener?.remove()
        
        isLoading = true
        
        reviewsListener = db.collection("reviews")
            .whereField("businessId", isEqualTo: businessId)
            .order(by: "createdAt", descending: true)
            .limit(to: 20) // Limit to 20 reviews for performance
            .addSnapshotListener { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Failed to load reviews: \(error.localizedDescription)"
                    print("Error fetching reviews: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No reviews found")
                    return
                }
                
                self?.reviews = documents.compactMap { doc -> Review? in
                    try? doc.data(as: Review.self)
                }
                
                print("✅ Loaded \(self?.reviews.count ?? 0) reviews")
            }
    }
    
    // Fetch user reviews (for profile view)
    func fetchUserReviews(userId: String) {
        reviewsListener?.remove()
        
        reviewsListener = db.collection("reviews")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50) // Limit user reviews
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching user reviews: \(error)")
                    return
                }
                
                self?.reviews = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: Review.self)
                } ?? []
            }
    }
    
    // Add a new review
    func addReview(_ review: Review, completion: @escaping (Bool, String) -> Void) {
        guard Auth.auth().currentUser != nil else {
            completion(false, "You must be logged in to add a review")
            return
        }
        
        // Check if user already reviewed this business
        db.collection("reviews")
            .whereField("businessId", isEqualTo: review.businessId)
            .whereField("userId", isEqualTo: review.userId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion(false, "Error: \(error.localizedDescription)")
                    return
                }
                
                if let existingReview = snapshot?.documents.first {
                    // Update existing review
                    var updatedReview = review
                    updatedReview.id = existingReview.documentID
                    self?.updateReview(updatedReview, completion: completion)
                } else {
                    // Add new review
                    do {
                        let _ = try self?.db.collection("reviews").addDocument(from: review) { error in
                            if let error = error {
                                completion(false, "Failed to add review: \(error.localizedDescription)")
                            } else {
                                // Update business rating immediately (not in background)
                                self?.updateBusinessRating(businessId: review.businessId) { success in
                                    if success {
                                        completion(true, "✅ Review added successfully!")
                                    } else {
                                        completion(true, "✅ Review added but rating update delayed")
                                    }
                                }
                            }
                        }
                    } catch {
                        completion(false, "Failed to encode review: \(error.localizedDescription)")
                    }
                }
            }
    }
    
    // Update an existing review
    func updateReview(_ review: Review, completion: @escaping (Bool, String) -> Void) {
        guard let reviewId = review.id else {
            completion(false, "Invalid review ID")
            return
        }
        
        do {
            try db.collection("reviews").document(reviewId).setData(from: review) { error in
                if let error = error {
                    completion(false, "Failed to update review: \(error.localizedDescription)")
                } else {
                    // Update business rating immediately
                    self.updateBusinessRating(businessId: review.businessId) { success in
                        if success {
                            completion(true, "✅ Review updated successfully!")
                        } else {
                            completion(true, "✅ Review updated but rating update delayed")
                        }
                    }
                }
            }
        } catch {
            completion(false, "Failed to encode review: \(error.localizedDescription)")
        }
    }
    
    // Delete a review
    func deleteReview(_ review: Review, completion: @escaping (Bool, String) -> Void) {
        guard let reviewId = review.id else {
            completion(false, "Invalid review ID")
            return
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false, "You must be logged in")
            return
        }
        
        guard review.userId == userId else {
            completion(false, "You can only delete your own reviews")
            return
        }
        
        db.collection("reviews").document(reviewId).delete { error in
            if let error = error {
                completion(false, "Failed to delete review: \(error.localizedDescription)")
            } else {
                // Update business rating immediately
                self.updateBusinessRating(businessId: review.businessId) { success in
                    if success {
                        completion(true, "✅ Review deleted successfully!")
                    } else {
                        completion(true, "✅ Review deleted but rating update delayed")
                    }
                }
            }
        }
    }
    
    // Update business rating based on reviews (synchronous with completion)
    private func updateBusinessRating(businessId: String, completion: @escaping (Bool) -> Void) {
        db.collection("reviews")
            .whereField("businessId", isEqualTo: businessId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error fetching reviews for rating update: \(error)")
                    completion(false)
                    return
                }
                
                let reviews = snapshot?.documents.compactMap { doc -> Review? in
                    try? doc.data(as: Review.self)
                } ?? []
                
                let totalRating = reviews.reduce(0.0) { $0 + $1.rating }
                let averageRating = reviews.isEmpty ? 0.0 : totalRating / Double(reviews.count)
                let reviewCount = reviews.count
                
                // Update business document
                self?.db.collection("businesses").document(businessId).updateData([
                    "rating": averageRating,
                    "reviewCount": reviewCount
                ]) { error in
                    if let error = error {
                        print("❌ Error updating business rating: \(error)")
                        completion(false)
                    } else {
                        print("✅ Business rating updated: \(String(format: "%.1f", averageRating)) (\(reviewCount) reviews)")
                        completion(true)
                    }
                }
            }
    }
    
    // Add owner response to a review
    func addOwnerResponse(to review: Review, response: String, completion: @escaping (Bool, String) -> Void) {
        guard let reviewId = review.id else {
            completion(false, "Invalid review ID")
            return
        }
        
        db.collection("reviews").document(reviewId).updateData([
            "isOwnerResponse": true,
            "ownerResponse": response,
            "ownerResponseDate": Date()
        ]) { error in
            if let error = error {
                completion(false, "Failed to add response: \(error.localizedDescription)")
            } else {
                completion(true, "✅ Response added successfully!")
            }
        }
    }
    
    // Get live rating and count for a business
    func getLiveRating() -> (rating: Double, count: Int) {
        guard !reviews.isEmpty else { return (0.0, 0) }
        let total = reviews.reduce(0.0) { $0 + $1.rating }
        return (total / Double(reviews.count), reviews.count)
    }
}
