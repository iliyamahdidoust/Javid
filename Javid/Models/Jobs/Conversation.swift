import Foundation
import FirebaseFirestore

// MARK: - Conversation Model
struct Conversation: Identifiable, Codable {
    @DocumentID var id: String?
    var conversationId: String
    var jobId: String
    var jobTitle: String
    var applicationId: String
    var applicantId: String
    var applicantName: String
    var employerId: String
    var employerName: String
    var companyName: String
    var lastMessage: String
    var lastMessageSenderId: String
    var lastMessageAt: Date
    var unreadCount: Int = 0
    var isActive: Bool = true
    
    // Determine the other party based on current user
    func otherPartyName(currentUserId: String) -> String {
        return currentUserId == applicantId ? companyName : applicantName
    }
    
    func otherPartyId(currentUserId: String) -> String {
        return currentUserId == applicantId ? employerId : applicantId
    }
    
    init(
        conversationId: String,
        jobId: String,
        jobTitle: String,
        applicationId: String,
        applicantId: String,
        applicantName: String,
        employerId: String,
        employerName: String,
        companyName: String
    ) {
        self.conversationId = conversationId
        self.jobId = jobId
        self.jobTitle = jobTitle
        self.applicationId = applicationId
        self.applicantId = applicantId
        self.applicantName = applicantName
        self.employerId = employerId
        self.employerName = employerName
        self.companyName = companyName
        self.lastMessage = ""
        self.lastMessageSenderId = ""
        self.lastMessageAt = Date()
    }
}
