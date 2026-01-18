import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class JobMessagingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var conversations: [Conversation] = []
    @Published var messages: [JobMessage] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var conversationsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    
    deinit {
        conversationsListener?.remove()
        messagesListener?.remove()
    }
    
    // MARK: - Fetch User Conversations
    func fetchConversations() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            return
        }
        
        isLoading = true
        
        // Remove previous listener
        conversationsListener?.remove()
        
        // Fetch conversations where user is either applicant or employer
        conversationsListener = db.collection("conversations")
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Failed to load conversations: \(error.localizedDescription)"
                    print("❌ Error fetching conversations: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No conversations found")
                    return
                }
                
                // Filter conversations where user is involved
                self?.conversations = documents.compactMap { doc -> Conversation? in
                    guard let conversation = try? doc.data(as: Conversation.self) else { return nil }
                    return (conversation.applicantId == userId || conversation.employerId == userId) ? conversation : nil
                }
                
                print("✅ Loaded \(self?.conversations.count ?? 0) conversations")
            }
    }
    
    // MARK: - Fetch Messages for Conversation
    func fetchMessages(conversationId: String) {
        messagesListener?.remove()
        
        messagesListener = db.collection("job_messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "sentAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error fetching messages: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No messages found")
                    return
                }
                
                self?.messages = documents.compactMap { doc -> JobMessage? in
                    try? doc.data(as: JobMessage.self)
                }
                
                // Mark messages as read
                self?.markMessagesAsRead(conversationId: conversationId)
                
                print("✅ Loaded \(self?.messages.count ?? 0) messages")
            }
    }
    
    // MARK: - Send Message
    func sendMessage(
        conversationId: String,
        jobId: String,
        applicationId: String,
        recipientId: String,
        recipientName: String,
        message: String,
        attachmentURL: String? = nil,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let userId = Auth.auth().currentUser?.uid,
              let userName = Auth.auth().currentUser?.displayName else {
            completion(false, "You must be logged in")
            return
        }
        
        let jobMessage = JobMessage(
            conversationId: conversationId,
            jobId: jobId,
            applicationId: applicationId,
            senderId: userId,
            senderName: userName,
            recipientId: recipientId,
            recipientName: recipientName,
            message: message,
            attachmentURL: attachmentURL
        )
        
        do {
            try db.collection("job_messages").addDocument(from: jobMessage) { [weak self] error in
                if let error = error {
                    completion(false, "Failed to send message: \(error.localizedDescription)")
                } else {
                    // Update conversation's last message
                    self?.updateConversationLastMessage(
                        conversationId: conversationId,
                        message: message,
                        senderId: userId
                    )
                    completion(true, "✅ Message sent")
                }
            }
        } catch {
            completion(false, "Failed to encode message: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Start Conversation (Employer initiates)
    func startConversation(
        application: JobApplication,
        job: Job,
        initialMessage: String,
        completion: @escaping (Bool, String, String?) -> Void
    ) {
        guard let userId = Auth.auth().currentUser?.uid,
              let userName = Auth.auth().currentUser?.displayName else {
            completion(false, "You must be logged in", nil)
            return
        }
        
        // Check if conversation already exists
        let conversationId = "\(job.id ?? "")_\(application.applicantId)"
        
        db.collection("conversations")
            .whereField("conversationId", isEqualTo: conversationId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion(false, "Error: \(error.localizedDescription)", nil)
                    return
                }
                
                if let existingConversation = snapshot?.documents.first {
                    // Conversation exists, just send message
                    self?.sendMessage(
                        conversationId: conversationId,
                        jobId: job.id ?? "",
                        applicationId: application.id ?? "",
                        recipientId: application.applicantId,
                        recipientName: application.applicantName,
                        message: initialMessage
                    ) { success, message in
                        completion(success, message, conversationId)
                    }
                } else {
                    // Create new conversation
                    let conversation = Conversation(
                        conversationId: conversationId,
                        jobId: job.id ?? "",
                        jobTitle: job.title,
                        applicationId: application.id ?? "",
                        applicantId: application.applicantId,
                        applicantName: application.applicantName,
                        employerId: userId,
                        employerName: userName,
                        companyName: job.company
                    )
                    
                    do {
                        try self?.db.collection("conversations").addDocument(from: conversation) { error in
                            if let error = error {
                                completion(false, "Failed to create conversation: \(error.localizedDescription)", nil)
                            } else {
                                // Send initial message
                                self?.sendMessage(
                                    conversationId: conversationId,
                                    jobId: job.id ?? "",
                                    applicationId: application.id ?? "",
                                    recipientId: application.applicantId,
                                    recipientName: application.applicantName,
                                    message: initialMessage
                                ) { success, message in
                                    completion(success, message, conversationId)
                                }
                            }
                        }
                    } catch {
                        completion(false, "Failed to encode conversation: \(error.localizedDescription)", nil)
                    }
                }
            }
    }
    
    // MARK: - Update Conversation Last Message
    private func updateConversationLastMessage(conversationId: String, message: String, senderId: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("conversations")
            .whereField("conversationId", isEqualTo: conversationId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error updating conversation: \(error)")
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    print("❌ Conversation not found")
                    return
                }
                
                // Increment unread count for recipient
                let updates: [String: Any] = [
                    "lastMessage": message,
                    "lastMessageSenderId": senderId,
                    "lastMessageAt": Date(),
                    "unreadCount": senderId != userId ? FieldValue.increment(Int64(1)) : 0
                ]
                
                self?.db.collection("conversations").document(document.documentID).updateData(updates)
            }
    }
    
    // MARK: - Mark Messages as Read
    private func markMessagesAsRead(conversationId: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("job_messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .whereField("recipientId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error marking messages as read: \(error)")
                    return
                }
                
                let batch = self?.db.batch()
                
                snapshot?.documents.forEach { document in
                    batch?.updateData(["isRead": true], forDocument: document.reference)
                }
                
                batch?.commit { error in
                    if let error = error {
                        print("❌ Error committing batch: \(error)")
                    } else {
                        // Reset unread count in conversation
                        self?.resetUnreadCount(conversationId: conversationId)
                    }
                }
            }
    }
    
    // MARK: - Reset Unread Count
    private func resetUnreadCount(conversationId: String) {
        db.collection("conversations")
            .whereField("conversationId", isEqualTo: conversationId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error resetting unread count: \(error)")
                    return
                }
                
                guard let document = snapshot?.documents.first else { return }
                
                self?.db.collection("conversations").document(document.documentID).updateData([
                    "unreadCount": 0
                ])
            }
    }
    
    // MARK: - Get Total Unread Count
    func getTotalUnreadCount() -> Int {
        guard let userId = Auth.auth().currentUser?.uid else { return 0 }
        
        return conversations
            .filter { conversation in
                // Count unread if user is recipient of last message
                conversation.lastMessageSenderId != userId
            }
            .reduce(0) { $0 + $1.unreadCount }
    }
    
    // MARK: - Check if Conversation Exists
    func conversationExists(conversationId: String, completion: @escaping (Bool) -> Void) {
        db.collection("conversations")
            .whereField("conversationId", isEqualTo: conversationId)
            .getDocuments { snapshot, error in
                if error != nil {
                    completion(false)
                    return
                }
                
                completion(!(snapshot?.documents.isEmpty ?? true))
            }
    }
}
