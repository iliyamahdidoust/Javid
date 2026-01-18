import Foundation
import FirebaseFirestore

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    var uid: String
    var email: String
    var name: String
    var isBusinessOwner: Bool
    var createdAt: Date
    
    init(uid: String, email: String, name: String, isBusinessOwner: Bool) {
        self.uid = uid
        self.email = email
        self.name = name
        self.isBusinessOwner = isBusinessOwner
        self.createdAt = Date()
    }
}
