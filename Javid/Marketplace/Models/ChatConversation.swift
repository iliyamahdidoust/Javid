import Foundation
import FirebaseFirestore

// MARK: - Chat Conversation Model
struct ChatConversation: Identifiable, Codable {
    @DocumentID var id: String?
    var participantIds: [String] // Array of user IDs
    var participantNames: [String: String] // userId: userName
    var participantEmails: [String: String] // userId: userEmail
    var lastMessage: String
    var lastMessageTimestamp: Date
    var lastMessageSenderId: String
    var itemId: String // The marketplace item being discussed
    var itemTitle: String
    var itemPrice: Double
    var itemPhotoURL: String?
    var unreadCount: [String: Int] // userId: unreadCount
    var createdAt: Date
    
    // Helper to get other participant
    func getOtherParticipantId(currentUserId: String) -> String? {
        return participantIds.first(where: { $0 != currentUserId })
    }
    
    func getOtherParticipantName(currentUserId: String) -> String {
        if let otherId = getOtherParticipantId(currentUserId: currentUserId) {
            return participantNames[otherId] ?? "Unknown"
        }
        return "Unknown"
    }
    
    func getUnreadCount(for userId: String) -> Int {
        return unreadCount[userId] ?? 0
    }
    
    init(
        id: String? = nil,
        participantIds: [String],
        participantNames: [String: String],
        participantEmails: [String: String],
        lastMessage: String,
        lastMessageTimestamp: Date,
        lastMessageSenderId: String,
        itemId: String,
        itemTitle: String,
        itemPrice: Double,
        itemPhotoURL: String?,
        unreadCount: [String: Int],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.participantIds = participantIds
        self.participantNames = participantNames
        self.participantEmails = participantEmails
        self.lastMessage = lastMessage
        self.lastMessageTimestamp = lastMessageTimestamp
        self.lastMessageSenderId = lastMessageSenderId
        self.itemId = itemId
        self.itemTitle = itemTitle
        self.itemPrice = itemPrice
        self.itemPhotoURL = itemPhotoURL
        self.unreadCount = unreadCount
        self.createdAt = createdAt
    }
}

// MARK: - Message Model
struct Message: Identifiable, Codable {
    @DocumentID var id: String?
    var conversationId: String
    var senderId: String
    var senderName: String
    var text: String
    var timestamp: Date
    var isRead: Bool
    
    init(
        id: String? = nil,
        conversationId: String,
        senderId: String,
        senderName: String,
        text: String,
        timestamp: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
        self.isRead = isRead
    }
}
