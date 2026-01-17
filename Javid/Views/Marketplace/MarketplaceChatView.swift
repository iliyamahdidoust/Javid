import SwiftUI
import FirebaseAuth

// MARK: - Marketplace Chat View
struct MarketplaceChatView: View {
    let conversation: ChatConversation
    @ObservedObject var messagingViewModel: MessagingViewModel
    
    @State private var messageText = ""
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isKeyboardVisible = false
    @State private var isSending = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    var otherParticipantName: String {
        conversation.getOtherParticipantName(currentUserId: currentUserId)
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Item Preview
                itemPreviewSection
                
                // Messages
                messagesSection
                
                // Input Area
                messageInputSection
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupChat()
        }
        .onDisappear {
            cleanupChat()
        }
        // ✅ Keyboard handling
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scrollToBottom(animated: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }
    
    // MARK: - Setup Chat
    func setupChat() {
        guard let conversationId = conversation.id else {
            print("❌ Invalid conversation ID")
            return
        }
        
        print("🔧 Setting up chat for conversation: \(conversationId)")
        messagingViewModel.setupMessagesListener(conversationId: conversationId)
        messagingViewModel.markConversationAsRead(conversationId: conversationId)
        
        // ✅ Scroll to bottom after messages load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            scrollToBottom(animated: false)
        }
    }
    
    // MARK: - Cleanup Chat
    func cleanupChat() {
        print("🧹 Cleaning up chat")
        messagingViewModel.clearMessagesListener()
    }
    
    // MARK: - Header Section
    var headerSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                }
                
                // Avatar
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Text(otherParticipantName.prefix(1).uppercased())
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(otherParticipantName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Active")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.success)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppColors.surface)
            
            Divider()
        }
    }
    
    // MARK: - Item Preview Section
    var itemPreviewSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Item Image
                if let photoURL = conversation.itemPhotoURL,
                   let url = URL(string: photoURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } placeholder: {
                        ZStack {
                            Color.gray.opacity(0.2)
                            ProgressView()
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.itemTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    Text(String(format: "$%.2f", conversation.itemPrice))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.primary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(12)
            .background(
                colorScheme == .dark
                    ? Color(white: 0.15)
                    : Color(white: 0.97)
            )
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            Divider()
        }
    }
    
    // MARK: - Messages Section - FIXED
    var messagesSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messagingViewModel.currentMessages.isEmpty {
                        // ✅ Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 50, weight: .light))
                                .foregroundColor(AppColors.textTertiary)
                            
                            Text("Start the conversation")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        ForEach(messagingViewModel.currentMessages) { message in
                            MarketplaceMessageBubble(
                                message: message,
                                isFromCurrentUser: message.senderId == currentUserId
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 20) // ✅ Extra padding at bottom
            }
            .onAppear {
                scrollProxy = proxy
            }
            .onChange(of: messagingViewModel.currentMessages.count) { _ in
                scrollToBottom(animated: true)
            }
        }
    }
    
    // MARK: - Message Input Section - FIXED
    var messageInputSection: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Text Field
                ZStack(alignment: .leading) {
                    if messageText.isEmpty {
                        Text("Type a message...")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textTertiary)
                            .padding(.leading, 12)
                    }
                    
                    TextField("", text: $messageText, axis: .vertical)
                        .font(.system(size: 16))
                        .padding(12)
                        .lineLimit(1...5)
                        .disabled(isSending)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.95))
                )
                
                // Send Button
                Button(action: sendMessage) {
                    ZStack {
                        Circle()
                            .fill(
                                messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending
                                    ? AppColors.textTertiary.opacity(0.3)
                                    : AppColors.primary
                            )
                            .frame(width: 44, height: 44)
                        
                        if isSending {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppColors.surface)
        }
    }
    
    // MARK: - Send Message - FIXED
    func sendMessage() {
        guard let conversationId = conversation.id else {
            print("❌ Invalid conversation ID")
            return
        }
        
        guard let currentUser = Auth.auth().currentUser,
              let currentUserName = currentUser.displayName else {
            print("❌ User not authenticated")
            return
        }
        
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            print("⚠️ Empty message")
            return
        }
        
        // ✅ Clear input and set sending state immediately
        let messageToSend = text
        messageText = ""
        isSending = true
        
        // ✅ Hide keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        print("📤 Sending message: \(messageToSend)")
        
        messagingViewModel.sendMessage(
            conversationId: conversationId,
            text: messageToSend,
            senderId: currentUser.uid,
            senderName: currentUserName
        ) { success, message in
            DispatchQueue.main.async {
                isSending = false
                
                if success {
                    print("✅ Message sent successfully")
                    // Scroll to bottom after message is sent
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollToBottom(animated: true)
                    }
                } else {
                    print("❌ Failed to send message: \(message)")
                    // ✅ Restore message on failure
                    messageText = messageToSend
                }
            }
        }
    }
    
    // MARK: - Scroll to Bottom - FIXED
    func scrollToBottom(animated: Bool) {
        guard let lastMessage = messagingViewModel.currentMessages.last,
              let scrollProxy = scrollProxy else {
            return
        }
        
        if animated {
            withAnimation(.easeOut(duration: 0.3)) {
                scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        } else {
            scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

// MARK: - Marketplace Message Bubble - FIXED
struct MarketplaceMessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // ✅ Show sender name for messages from others
                if !isFromCurrentUser {
                    Text(message.senderName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 4)
                }
                
                Text(message.text)
                    .font(.system(size: 16))
                    .foregroundColor(isFromCurrentUser ? .white : AppColors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        isFromCurrentUser
                            ? AppColors.primary
                            : (colorScheme == .dark
                                ? Color(white: 0.2)
                                : Color(white: 0.95))
                    )
                    .cornerRadius(20)
                
                HStack(spacing: 4) {
                    Text(message.timestamp.timeAgo())
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary)
                    
                    // ✅ Read indicator for sent messages
                    if isFromCurrentUser {
                        Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 10))
                            .foregroundColor(message.isRead ? AppColors.primary : AppColors.textTertiary)
                    }
                }
                .padding(.horizontal, 4)
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
}
