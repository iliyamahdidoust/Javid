import SwiftUI
import FirebaseAuth

struct MarketplaceMessagesListView: View {
    @StateObject private var messagingViewModel = MessagingViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showingDeleteAlert = false
    @State private var conversationToDelete: ChatConversation?
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    if messagingViewModel.isLoading && messagingViewModel.conversations.isEmpty {
                        loadingView
                    } else if messagingViewModel.conversations.isEmpty {
                        emptyStateView
                    } else {
                        conversationsListView
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("Delete Conversation", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    conversationToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let conversation = conversationToDelete {
                        deleteConversation(conversation)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this conversation? This action cannot be undone.")
            }
            .refreshable {
                await refreshConversations()
            }
            .onAppear {
                // ✅ Ensure listener is active
                messagingViewModel.setupConversationsListener()
            }
        }
    }
    
    // MARK: - Header Section
    var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Messages")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                
                if messagingViewModel.totalUnreadCount > 0 {
                    ZStack {
                        Circle()
                            .fill(AppColors.error)
                            .frame(width: 24, height: 24)
                        
                        Text("\(messagingViewModel.totalUnreadCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(AppColors.surface)
            
            Divider()
        }
    }
    
    // MARK: - Loading View
    var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading conversations...")
                .font(.system(size: 16))
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
        }
    }
    
    // MARK: - Conversations List - FIXED
    var conversationsListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(messagingViewModel.conversations) { conversation in
                    NavigationLink(
                        destination: MarketplaceChatView(
                            conversation: conversation,
                            messagingViewModel: messagingViewModel
                        )
                    ) {
                        MarketplaceConversationRow(
                            conversation: conversation,
                            currentUserId: Auth.auth().currentUser?.uid ?? ""
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            conversationToDelete = conversation
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    
                    if conversation.id != messagingViewModel.conversations.last?.id {
                        Divider()
                            .padding(.leading, 88)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "message")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(AppColors.textTertiary)
            
            Text("No Messages Yet")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("Start a conversation by messaging a seller about their item")
                .font(.system(size: 16))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Delete Conversation - FIXED
    func deleteConversation(_ conversation: ChatConversation) {
        guard let conversationId = conversation.id else {
            print("❌ Invalid conversation ID")
            return
        }
        
        messagingViewModel.deleteConversation(conversationId: conversationId) { success, message in
            DispatchQueue.main.async {
                if success {
                    print("✅ \(message)")
                } else {
                    print("❌ \(message)")
                }
                conversationToDelete = nil
            }
        }
    }
    
    // MARK: - Refresh Conversations
    @MainActor
    func refreshConversations() async {
        isRefreshing = true
        messagingViewModel.refreshConversations()
        
        // Wait a bit for the refresh to complete
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        isRefreshing = false
    }
}

// MARK: - Marketplace Conversation Row - FIXED

struct MarketplaceConversationRow: View {
    let conversation: ChatConversation
    let currentUserId: String
    
    @Environment(\.colorScheme) var colorScheme
    
    var isUnread: Bool {
        conversation.getUnreadCount(for: currentUserId) > 0
    }
    
    var otherParticipantName: String {
        conversation.getOtherParticipantName(currentUserId: currentUserId)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Item Image
            if let photoURL = conversation.itemPhotoURL,
               let url = URL(string: photoURL) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    ZStack {
                        Color.gray.opacity(0.2)
                        ProgressView()
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                ZStack {
                    Color.gray.opacity(0.2)
                    Image(systemName: "photo")
                        .foregroundColor(AppColors.textTertiary)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Message Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(otherParticipantName)
                        .font(.system(size: 16, weight: isUnread ? .bold : .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(conversation.lastMessageTimestamp.timeAgo())
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textTertiary)
                }
                
                Text(conversation.itemTitle)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.primary)
                    .lineLimit(1)
                
                HStack {
                    // ✅ Show who sent the last message
                    if conversation.lastMessageSenderId == currentUserId {
                        Text("You: ")
                            .font(.system(size: 14, weight: isUnread ? .semibold : .regular))
                            .foregroundColor(AppColors.textSecondary)
                        +
                        Text(conversation.lastMessage)
                            .font(.system(size: 14, weight: isUnread ? .semibold : .regular))
                            .foregroundColor(isUnread ? AppColors.textPrimary : AppColors.textSecondary)
                    } else {
                        Text(conversation.lastMessage)
                            .font(.system(size: 14, weight: isUnread ? .semibold : .regular))
                            .foregroundColor(isUnread ? AppColors.textPrimary : AppColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    if isUnread {
                        ZStack {
                            Circle()
                                .fill(AppColors.primary)
                                .frame(width: 20, height: 20)
                            
                            Text("\(conversation.getUnreadCount(for: currentUserId))")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            isUnread
                ? (colorScheme == .dark
                    ? AppColors.primary.opacity(0.05)
                    : AppColors.primary.opacity(0.03))
                : AppColors.surface
        )
        .contentShape(Rectangle()) // ✅ Make entire area tappable
    }
}
