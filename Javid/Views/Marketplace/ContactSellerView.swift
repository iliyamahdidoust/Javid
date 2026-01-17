import SwiftUI
import FirebaseAuth

struct ContactSellerView: View {
    let item: MarketplaceItem
    
    @StateObject private var messagingViewModel = MessagingViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var messageText: String = ""
    @State private var isCreatingConversation = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var navigateToChat = false
    @State private var createdConversation: ChatConversation?
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Item Preview
                        itemPreviewSection
                        
                        // Seller Info
                        sellerInfoSection
                        
                        // Message Box
                        messageBoxSection
                        
                        // Send Button
                        sendButtonSection
                    }
                    .padding(20)
                }
            }
            
            // Loading Overlay
            if isCreatingConversation {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Starting conversation...")
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
            }
            
            // Hidden NavigationLink
            if let conversation = createdConversation {
                NavigationLink(
                    destination: MarketplaceChatView(conversation: conversation, messagingViewModel: messagingViewModel),
                    isActive: $navigateToChat
                ) {
                    EmptyView()
                }
                .hidden()
            }
        }
        .navigationBarHidden(true)
        .alert("Message", isPresented: $showingAlert) {
            Button("OK") {
                // ✅ Dismiss if it's a "can't message yourself" error
                if alertMessage.contains("cannot message yourself") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            // ✅ Check if user is trying to message themselves
            if let currentUserId = Auth.auth().currentUser?.uid,
               currentUserId == item.sellerId {
                alertMessage = "You cannot message yourself about your own item"
                showingAlert = true
                return
            }
            
            // Set default message
            messageText = "Hi, is this still available?"
        }
    }
    
    // MARK: - Header Section
    var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Text("Contact Seller")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(AppColors.surface)
            
            Divider()
        }
    }
    
    // MARK: - Item Preview Section
    var itemPreviewSection: some View {
        HStack(spacing: 12) {
            // Item Image
            if let firstPhotoURL = item.photoURLs.first,
               let url = URL(string: firstPhotoURL) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } placeholder: {
                    ZStack {
                        Color.gray.opacity(0.2)
                        ProgressView()
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                
                Text(item.formattedPrice)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.primary)
                
                Text(item.location)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(AppColors.surface)
        .cornerRadius(12)
    }
    
    // MARK: - Seller Info Section
    var sellerInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seller")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Text(item.sellerName.prefix(1).uppercased())
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.sellerName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(item.sellerEmail)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
            }
            .padding(16)
            .background(AppColors.surface)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Message Box Section
    var messageBoxSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Message")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            
            ZStack(alignment: .topLeading) {
                if messageText.isEmpty {
                    Text("Type your message here...")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                
                TextEditor(text: $messageText)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(minHeight: 120)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
            }
            .background(AppColors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Send Button Section
    var sendButtonSection: some View {
        Button(action: sendMessage) {
            HStack {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                
                Text("Send Message")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                messageText.trimmingCharacters(in: .whitespaces).isEmpty
                    ? LinearGradient(
                        colors: [AppColors.textTertiary, AppColors.textTertiary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
            )
            .cornerRadius(12)
            .shadow(
                color: messageText.trimmingCharacters(in: .whitespaces).isEmpty
                    ? Color.clear
                    : AppColors.primary.opacity(0.3),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || isCreatingConversation)
    }
    
    // MARK: - Send Message - FULLY FIXED
    func sendMessage() {
        guard let currentUser = Auth.auth().currentUser,
              let currentUserName = currentUser.displayName,
              let currentUserEmail = currentUser.email else {
            alertMessage = "Please login to send messages"
            showingAlert = true
            return
        }
        
        // ✅ Check if trying to message yourself
        if currentUser.uid == item.sellerId {
            alertMessage = "You cannot message yourself about your own item"
            showingAlert = true
            return
        }
        
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            alertMessage = "Please enter a message"
            showingAlert = true
            return
        }
        
        isCreatingConversation = true
        
        messagingViewModel.createOrGetConversation(
            item: item,
            currentUserId: currentUser.uid,
            currentUserName: currentUserName,
            currentUserEmail: currentUserEmail
        ) { result in
            DispatchQueue.main.async {
                isCreatingConversation = false
                
                switch result {
                case .success(let conversation):
                    print("✅ Conversation ready: \(conversation.id ?? "unknown")")
                    
                    // ✅ If user customized the message, send it
                    if trimmedMessage != "Hi, is this still available?" {
                        messagingViewModel.sendMessage(
                            conversationId: conversation.id ?? "",
                            text: trimmedMessage,
                            senderId: currentUser.uid,
                            senderName: currentUserName
                        ) { success, message in
                            DispatchQueue.main.async {
                                if !success {
                                    print("⚠️ Failed to send custom message: \(message)")
                                }
                                // ✅ Navigate regardless
                                createdConversation = conversation
                                navigateToChat = true
                            }
                        }
                    } else {
                        // ✅ Navigate with default message
                        createdConversation = conversation
                        navigateToChat = true
                    }
                    
                case .failure(let error):
                    print("❌ Failed to create conversation: \(error.localizedDescription)")
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
}
