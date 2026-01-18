import Foundation
import FirebaseFirestore

struct Favorite: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var businessId: String
    var createdAt: Date
    
    init(userId: String, businessId: String) {
        self.userId = userId
        self.businessId = businessId
        self.createdAt = Date()
    }
}
