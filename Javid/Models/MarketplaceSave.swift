import Foundation
import FirebaseFirestore

// MARK: - Marketplace Save Model (for saved items)
struct MarketplaceSave: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var itemId: String
    var createdAt: Date
    
    init(userId: String, itemId: String) {
        self.userId = userId
        self.itemId = itemId
        self.createdAt = Date()
    }
}
