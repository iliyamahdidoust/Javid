import Foundation
import FirebaseFirestore

// MARK: - Job Message Model
struct JobMessage: Codable, Identifiable {
    @DocumentID var id: String?
    var conversationId: String // jobId + applicantId
    var jobId: String
    var applicationId: String
    var senderId: String
    var senderName: String
    var recipientId: String
    var recipientName: String
    var message: String
    var attachmentURL: String?
    var isRead: Bool = false
    var sentAt: Date
    
    init(
        conversationId: String,
        jobId: String,
        applicationId: String,
        senderId: String,
        senderName: String,
        recipientId: String,
        recipientName: String,
        message: String,
        attachmentURL: String? = nil
    ) {
        self.conversationId = conversationId
        self.jobId = jobId
        self.applicationId = applicationId
        self.senderId = senderId
        self.senderName = senderName
        self.recipientId = recipientId
        self.recipientName = recipientName
        self.message = message
        self.attachmentURL = attachmentURL
        self.sentAt = Date()
    }
}
