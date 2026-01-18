import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class MessagingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var conversations: [ChatConversation] = []
    @Published var currentMessages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var totalUnreadCount = 0
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var conversationsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    
    // MARK: - Initialization
    init() {
        setupConversationsListener()
    }
    
    deinit {
        conversationsListener?.remove()
        messagesListener?.remove()
    }
    
    // MARK: - Setup Conversations Listener - FIXED SYNC
    func setupConversationsListener() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No user logged in")
            return
        }
        
        conversationsListener?.remove()
        
        print("📡 Setting up conversations listener for user: \(userId)")
        
        conversationsListener = db.collection("chat_conversations")
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastMessageTimestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error fetching conversations: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                    }
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("❌ No snapshot received")
                    return
                }
                
                print("📦 Received \(snapshot.documents.count) conversations")
                
                // ✅ Process document changes for real-time sync
                snapshot.documentChanges.forEach { change in
                    let conversationId = change.document.documentID
                    
                    switch change.type {
                    case .added:
                        print("➕ Conversation added: \(conversationId)")
                    case .modified:
                        print("🔄 Conversation modified: \(conversationId)")
                    case .removed:
                        print("➖ Conversation removed: \(conversationId)")
                    }
                }
                
                // ✅ Update conversations on main thread
                DispatchQueue.main.async {
                    self.conversations = snapshot.documents.compactMap { doc -> ChatConversation? in
                        do {
                            var conversation = try doc.data(as: ChatConversation.self)
                            conversation.id = doc.documentID
                            return conversation
                        } catch {
                            print("❌ Error decoding conversation \(doc.documentID): \(error)")
                            return nil
                        }
                    }
                    
                    // Calculate total unread count
                    self.totalUnreadCount = self.conversations.reduce(0) { total, conversation in
                        total + conversation.getUnreadCount(for: userId)
                    }
                    
                    print("✅ Loaded \(self.conversations.count) conversations, \(self.totalUnreadCount) unread")
                }
            }
    }
    
    // MARK: - Create or Get Conversation - FIXED
    func createOrGetConversation(
        item: MarketplaceItem,
        currentUserId: String,
        currentUserName: String,
        currentUserEmail: String,
        completion: @escaping (Result<ChatConversation, Error>) -> Void
    ) {
        let sellerId = item.sellerId
        
        // ✅ Don't allow messaging yourself
        guard currentUserId != sellerId else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "You cannot message yourself"])))
            return
        }
        
        guard let itemId = item.id else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid item ID"])))
            return
        }
        
        print("🔍 Looking for existing conversation for item: \(itemId)")
        
        // ✅ Check for existing conversation with proper query
        db.collection("chat_conversations")
            .whereField("itemId", isEqualTo: itemId)
            .whereField("participantIds", arrayContains: currentUserId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error checking for existing conversation: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                // Check if conversation with both participants exists
                if let existingDoc = snapshot?.documents.first(where: { doc in
                    let data = doc.data()
                    if let participantIds = data["participantIds"] as? [String] {
                        return participantIds.contains(currentUserId) && participantIds.contains(sellerId)
                    }
                    return false
                }) {
                    do {
                        var conversation = try existingDoc.data(as: ChatConversation.self)
                        conversation.id = existingDoc.documentID
                        print("✅ Found existing conversation: \(existingDoc.documentID)")
                        completion(.success(conversation))
                    } catch {
                        print("❌ Error decoding existing conversation: \(error)")
                        completion(.failure(error))
                    }
                    return
                }
                
                // Create new conversation
                print("📝 Creating new conversation for item: \(itemId)")
                self?.createNewConversation(
                    item: item,
                    currentUserId: currentUserId,
                    currentUserName: currentUserName,
                    currentUserEmail: currentUserEmail,
                    sellerId: sellerId,
                    completion: completion
                )
            }
    }
    
    // MARK: - Create New Conversation - FIXED SYNC
    private func createNewConversation(
        item: MarketplaceItem,
        currentUserId: String,
        currentUserName: String,
        currentUserEmail: String,
        sellerId: String,
        completion: @escaping (Result<ChatConversation, Error>) -> Void
    ) {
        guard let itemId = item.id else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid item ID"])))
            return
        }
        
        let participantIds = [currentUserId, sellerId]
        let participantNames: [String: String] = [
            currentUserId: currentUserName,
            sellerId: item.sellerName
        ]
        let participantEmails: [String: String] = [
            currentUserId: currentUserEmail,
            sellerId: item.sellerEmail
        ]
        
        let initialMessage = "Hi, is this still available?"
        
        let unreadCount: [String: Int] = [
            currentUserId: 0,
            sellerId: 1
        ]
        
        let docRef = db.collection("chat_conversations").document()
        let now = Timestamp(date: Date())
        
        // ✅ Create conversation data with proper Firestore types
        let conversationData: [String: Any] = [
            "participantIds": participantIds,
            "participantNames": participantNames,
            "participantEmails": participantEmails,
            "lastMessage": initialMessage,
            "lastMessageTimestamp": now,
            "lastMessageSenderId": currentUserId,
            "itemId": itemId,
            "itemTitle": item.title,
            "itemPrice": item.price,
            "itemPhotoURL": item.photoURLs.first ?? "",
            "unreadCount": unreadCount,
            "createdAt": now
        ]
        
        // ✅ Set data with proper error handling
        docRef.setData(conversationData) { [weak self] error in
            if let error = error {
                print("❌ Error creating conversation: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            print("✅ Conversation created: \(docRef.documentID)")
            
            // ✅ Send initial message
            self?.sendMessage(
                conversationId: docRef.documentID,
                text: initialMessage,
                senderId: currentUserId,
                senderName: currentUserName
            ) { success, message in
                if success {
                    print("✅ Initial message sent")
                } else {
                    print("⚠️ Failed to send initial message: \(message)")
                }
                
                // ✅ Return conversation even if initial message fails
                let conversation = ChatConversation(
                    id: docRef.documentID,
                    participantIds: participantIds,
                    participantNames: participantNames,
                    participantEmails: participantEmails,
                    lastMessage: initialMessage,
                    lastMessageTimestamp: Date(),
                    lastMessageSenderId: currentUserId,
                    itemId: itemId,
                    itemTitle: item.title,
                    itemPrice: item.price,
                    itemPhotoURL: item.photoURLs.first,
                    unreadCount: unreadCount,
                    createdAt: Date()
                )
                
                completion(.success(conversation))
            }
        }
    }
    
    // MARK: - Setup Messages Listener - FIXED SYNC
    func setupMessagesListener(conversationId: String) {
        print("📡 Setting up messages listener for: \(conversationId)")
        
        messagesListener?.remove()
        
        DispatchQueue.main.async {
            self.currentMessages = []
        }
        
        messagesListener = db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error fetching messages: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                    }
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("❌ No snapshot received")
                    return
                }
                
                print("📦 Received \(snapshot.documents.count) messages")
                
                // ✅ Process document changes
                snapshot.documentChanges.forEach { change in
                    switch change.type {
                    case .added:
                        print("➕ Message added: \(change.document.documentID)")
                    case .modified:
                        print("🔄 Message modified: \(change.document.documentID)")
                    case .removed:
                        print("➖ Message removed: \(change.document.documentID)")
                    }
                }
                
                // ✅ Update messages on main thread
                DispatchQueue.main.async {
                    self.currentMessages = snapshot.documents.compactMap { doc -> Message? in
                        do {
                            var message = try doc.data(as: Message.self)
                            message.id = doc.documentID
                            return message
                        } catch {
                            print("❌ Error decoding message \(doc.documentID): \(error)")
                            return nil
                        }
                    }
                    
                    print("✅ Loaded \(self.currentMessages.count) messages")
                }
            }
    }
    
    // MARK: - Send Message - FIXED SYNC
    func sendMessage(
        conversationId: String,
        text: String,
        senderId: String,
        senderName: String,
        completion: @escaping (Bool, String) -> Void
    ) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedText.isEmpty else {
            completion(false, "Message cannot be empty")
            return
        }
        
        guard !conversationId.isEmpty else {
            completion(false, "Invalid conversation ID")
            return
        }
        
        print("📤 Sending message to conversation: \(conversationId)")
        
        let messageRef = db.collection("messages").document()
        let now = Timestamp(date: Date())
        
        // ✅ Create message data with proper Firestore types
        let messageData: [String: Any] = [
            "conversationId": conversationId,
            "senderId": senderId,
            "senderName": senderName,
            "text": trimmedText,
            "timestamp": now,
            "isRead": false
        ]
        
        // ✅ Set message data
        messageRef.setData(messageData) { [weak self] error in
            if let error = error {
                print("❌ Error sending message: \(error.localizedDescription)")
                completion(false, "Failed to send message: \(error.localizedDescription)")
                return
            }
            
            print("✅ Message sent successfully: \(messageRef.documentID)")
            
            // ✅ Update conversation
            self?.updateConversation(
                conversationId: conversationId,
                lastMessage: trimmedText,
                senderId: senderId
            )
            
            completion(true, "Message sent")
        }
    }
    
    // MARK: - Update Conversation - FIXED SYNC
    private func updateConversation(conversationId: String, lastMessage: String, senderId: String) {
        print("🔄 Updating conversation: \(conversationId)")
        
        db.collection("chat_conversations").document(conversationId).getDocument { [weak self] snapshot, error in
            if let error = error {
                print("❌ Error getting conversation: \(error.localizedDescription)")
                return
            }
            
            guard let data = snapshot?.data() else {
                print("❌ No conversation data found")
                return
            }
            
            guard let participantIds = data["participantIds"] as? [String],
                  var unreadCount = data["unreadCount"] as? [String: Int] else {
                print("❌ Invalid conversation data")
                return
            }
            
            // ✅ Update unread counts
            for participantId in participantIds {
                if participantId == senderId {
                    unreadCount[participantId] = 0
                } else {
                    unreadCount[participantId] = (unreadCount[participantId] ?? 0) + 1
                }
            }
            
            let now = Timestamp(date: Date())
            
            // ✅ Update with proper Firestore types
            self?.db.collection("chat_conversations").document(conversationId).updateData([
                "lastMessage": lastMessage,
                "lastMessageTimestamp": now,
                "lastMessageSenderId": senderId,
                "unreadCount": unreadCount
            ]) { error in
                if let error = error {
                    print("❌ Error updating conversation: \(error.localizedDescription)")
                } else {
                    print("✅ Conversation updated successfully")
                }
            }
        }
    }
    
    // MARK: - Mark as Read - FIXED SYNC
    func markConversationAsRead(conversationId: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No user logged in")
            return
        }
        
        print("📖 Marking conversation as read: \(conversationId)")
        
        db.collection("chat_conversations").document(conversationId).getDocument { [weak self] snapshot, error in
            if let error = error {
                print("❌ Error getting conversation: \(error.localizedDescription)")
                return
            }
            
            guard let data = snapshot?.data(),
                  var unreadCount = data["unreadCount"] as? [String: Int] else {
                print("❌ Invalid conversation data")
                return
            }
            
            // ✅ Only update if user has unread messages
            guard (unreadCount[userId] ?? 0) > 0 else {
                print("ℹ️ No unread messages for user")
                return
            }
            
            unreadCount[userId] = 0
            
            self?.db.collection("chat_conversations").document(conversationId).updateData([
                "unreadCount": unreadCount
            ]) { error in
                if let error = error {
                    print("❌ Error marking as read: \(error.localizedDescription)")
                } else {
                    print("✅ Marked conversation as read")
                }
            }
        }
        
        // ✅ Mark all unread messages as read with batch update
        db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .whereField("senderId", isNotEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error getting unread messages: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("ℹ️ No unread messages to mark")
                    return
                }
                
                let batch = self?.db.batch()
                for doc in documents {
                    batch?.updateData(["isRead": true], forDocument: doc.reference)
                }
                
                batch?.commit { error in
                    if let error = error {
                        print("❌ Error marking messages as read: \(error.localizedDescription)")
                    } else {
                        print("✅ Marked \(documents.count) messages as read")
                    }
                }
            }
    }
    
    // MARK: - Delete Conversation - FIXED
    func deleteConversation(conversationId: String, completion: @escaping (Bool, String) -> Void) {
        print("🗑️ Deleting conversation: \(conversationId)")
        
        deleteMessagesInBatches(conversationId: conversationId) { [weak self] success in
            guard success else {
                completion(false, "Failed to delete messages")
                return
            }
            
            self?.db.collection("chat_conversations").document(conversationId).delete { error in
                if let error = error {
                    print("❌ Error deleting conversation: \(error.localizedDescription)")
                    completion(false, "Failed to delete conversation: \(error.localizedDescription)")
                } else {
                    print("✅ Conversation deleted successfully")
                    completion(true, "Conversation deleted")
                }
            }
        }
    }
    
    // MARK: - Delete Messages in Batches
    private func deleteMessagesInBatches(conversationId: String, completion: @escaping (Bool) -> Void) {
        db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .limit(to: 500)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error getting messages to delete: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("ℹ️ No messages to delete")
                    completion(true)
                    return
                }
                
                let batch = self?.db.batch()
                for doc in documents {
                    batch?.deleteDocument(doc.reference)
                }
                
                batch?.commit { error in
                    if let error = error {
                        print("❌ Error deleting messages batch: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("✅ Deleted \(documents.count) messages")
                        
                        if documents.count == 500 {
                            self?.deleteMessagesInBatches(conversationId: conversationId, completion: completion)
                        } else {
                            completion(true)
                        }
                    }
                }
            }
    }
    
    // MARK: - Clear Messages Listener
    func clearMessagesListener() {
        print("🧹 Clearing messages listener")
        messagesListener?.remove()
        messagesListener = nil
        
        DispatchQueue.main.async {
            self.currentMessages = []
        }
    }
    
    // MARK: - Refresh Conversations
    func refreshConversations() {
        conversationsListener?.remove()
        setupConversationsListener()
    }
}
