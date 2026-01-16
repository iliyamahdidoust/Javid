import SwiftUI
import FirebaseAuth

// MARK: - Job Messages View
struct JobMessagesView: View {
    @EnvironmentObject var messagingVM: JobMessagingViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Messages")
                            .font(AppFonts.largeTitle)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("\(messagingVM.conversations.count) conversations")
                            .font(AppFonts.callout)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.md)
                .background(AppColors.surface)
                
                // Conversations List
                if messagingVM.isLoading {
                    ProgressView("Loading messages...")
                        .padding()
                } else if messagingVM.conversations.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(messagingVM.conversations) { conversation in
                                NavigationLink(destination: ChatView(conversation: conversation)) {
                                    ConversationRow(conversation: conversation)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider()
                                    .padding(.leading, 80)
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if messagingVM.conversations.isEmpty {
                messagingVM.fetchConversations()
            }
        }
    }
    
    // MARK: - Empty State
    var emptyStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            
            Image(systemName: "envelope.open")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textTertiary)
            
            VStack(spacing: 8) {
                Text("No Messages")
                    .font(AppFonts.title2)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Employers will contact you here about your applications")
                    .font(AppFonts.callout)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
}

// MARK: - Conversation Row
struct ConversationRow: View {
    let conversation: Conversation
    
    var otherPartyName: String {
        guard let userId = Auth.auth().currentUser?.uid else { return "" }
        return conversation.otherPartyName(currentUserId: userId)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Text(otherPartyName.prefix(1).uppercased())
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(otherPartyName)
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Text(conversation.lastMessageAt.timeAgo())
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Text(conversation.jobTitle)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                
                HStack {
                    Text(conversation.lastMessage)
                        .font(AppFonts.callout)
                        .foregroundColor(conversation.unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.primary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(conversation.unreadCount > 0 ? AppColors.primary.opacity(0.05) : Color.clear)
    }
}

// MARK: - Chat View
struct ChatView: View {
    let conversation: Conversation
    
    @EnvironmentObject var messagingVM: JobMessagingViewModel
    @State private var messageText = ""
    @State private var isSending = false
    
    @Environment(\.colorScheme) var colorScheme
    
    var otherPartyName: String {
        guard let userId = Auth.auth().currentUser?.uid else { return "" }
        return conversation.otherPartyName(currentUserId: userId)
    }
    
    var otherPartyId: String {
        guard let userId = Auth.auth().currentUser?.uid else { return "" }
        return conversation.otherPartyId(currentUserId: userId)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messagingVM.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(AppSpacing.md)
                }
                .onChange(of: messagingVM.messages.count) { _ in
                    if let lastMessage = messagingVM.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input Bar
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .font(AppFonts.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppColors.surface)
                    .cornerRadius(AppRadius.full)
                    .lineLimit(1...5)
                
                Button(action: sendMessage) {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(messageText.isEmpty ? AppColors.textTertiary : AppColors.primary)
                    }
                }
                .disabled(messageText.isEmpty || isSending)
            }
            .padding(AppSpacing.md)
            .background(AppColors.background)
        }
        .background(AppColors.background)
        .navigationTitle(otherPartyName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            messagingVM.fetchMessages(conversationId: conversation.conversationId)
        }
    }
    
    func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        isSending = true
        let message = messageText
        messageText = ""
        
        messagingVM.sendMessage(
            conversationId: conversation.conversationId,
            jobId: conversation.jobId,
            applicationId: conversation.applicationId,
            recipientId: otherPartyId,
            recipientName: otherPartyName,
            message: message
        ) { success, _ in
            isSending = false
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: JobMessage
    
    var isCurrentUser: Bool {
        guard let userId = Auth.auth().currentUser?.uid else { return false }
        return message.senderId == userId
    }
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.message)
                    .font(AppFonts.body)
                    .foregroundColor(isCurrentUser ? .white : AppColors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isCurrentUser ? AppColors.primary : AppColors.surface)
                    .cornerRadius(AppRadius.md)
                
                HStack(spacing: 4) {
                    Text(message.sentAt.timeAgo())
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary)
                    
                    if isCurrentUser && message.isRead {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.success)
                    }
                }
            }
            
            if !isCurrentUser { Spacer() }
        }
    }
}

// MARK: - Placeholder Views for Employer (Simple stubs)

struct EmployerProfileView: View {
    var body: some View {
        Text("Employer Profile - Coming Soon")
            .font(AppFonts.title2)
    }
}

struct EditEmployerProfileView: View {
    var body: some View {
        Text("Edit Employer Profile - Coming Soon")
    }
}

struct PostJobView: View {
    var body: some View {
        Text("Post Job - Coming Soon")
    }
}

struct EmployerJobsView: View {
    var body: some View {
        Text("My Posted Jobs - Coming Soon")
    }
}
