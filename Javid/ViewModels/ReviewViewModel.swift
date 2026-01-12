import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class ReviewViewModel: ObservableObject {
    @Published var reviews: [Review] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let db = Firestore.firestore()
    
    // Fetch reviews for a specific business
    func fetchReviews(for businessId: String) {
        isLoading = true
        
        db.collection("reviews")
            .whereField("businessId", isEqualTo: businessId)
            .order(by: "createdAt", descending: true)
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
        db.collection("reviews")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
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
                                // Update business rating
                                self?.updateBusinessRating(businessId: review.businessId)
                                completion(true, "✅ Review added successfully!")
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
                    self.updateBusinessRating(businessId: review.businessId)
                    completion(true, "✅ Review updated successfully!")
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
        
        // Check if user owns this review
        guard review.userId == userId else {
            completion(false, "You can only delete your own reviews")
            return
        }
        
        db.collection("reviews").document(reviewId).delete { error in
            if let error = error {
                completion(false, "Failed to delete review: \(error.localizedDescription)")
            } else {
                self.updateBusinessRating(businessId: review.businessId)
                completion(true, "✅ Review deleted successfully!")
            }
        }
    }
    
    // Update business rating based on reviews
    private func updateBusinessRating(businessId: String) {
        db.collection("reviews")
            .whereField("businessId", isEqualTo: businessId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error calculating rating: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let reviews = documents.compactMap { doc -> Review? in
                    try? doc.data(as: Review.self)
                }
                
                let totalRating = reviews.reduce(0.0) { $0 + $1.rating }
                let averageRating = reviews.isEmpty ? 0.0 : totalRating / Double(reviews.count)
                let reviewCount = reviews.count
                
                // Update business
                self?.db.collection("businesses").document(businessId).updateData([
                    "rating": averageRating,
                    "reviewCount": reviewCount
                ]) { error in
                    if let error = error {
                        print("Error updating business rating: \(error)")
                    } else {
                        print("✅ Business rating updated: \(averageRating) (\(reviewCount) reviews)")
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
    
    // Get user's reviews
    func fetchUserReviews(userId: String, completion: @escaping ([Review]) -> Void) {
        db.collection("reviews")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching user reviews: \(error)")
                    completion([])
                    return
                }
                
                let reviews = snapshot?.documents.compactMap { doc -> Review? in
                    try? doc.data(as: Review.self)
                } ?? []
                
                completion(reviews)
            }
    }
}
