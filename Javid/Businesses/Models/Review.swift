import Foundation
import FirebaseFirestore

struct Review: Codable, Identifiable {
    @DocumentID var id: String?
    var businessId: String
    var userId: String
    var userName: String
    var userEmail: String
    var rating: Double // 1 to 5
    var comment: String
    var createdAt: Date
    var isOwnerResponse: Bool = false
    var ownerResponse: String?
    var ownerResponseDate: Date?
    
    init(businessId: String, userId: String, userName: String, userEmail: String, rating: Double, comment: String) {
        self.businessId = businessId
        self.userId = userId
        self.userName = userName
        self.userEmail = userEmail
        self.rating = rating
        self.comment = comment
        self.createdAt = Date()
    }
}
