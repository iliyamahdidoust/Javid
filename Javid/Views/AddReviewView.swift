import SwiftUI
import FirebaseAuth

struct AddReviewView: View {
    let business: Business
    @ObservedObject var reviewViewModel: ReviewViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var rating: Int = 5
    @State private var comment: String = ""
    @State private var isSubmitting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // Business Info
                        businessInfoSection
                        
                        // Rating Section
                        ratingSection
                        
                        // Comment Section
                        commentSection
                        
                        // Submit Button
                        submitButton
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle("Write a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Review", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {
                    if alertMessage.contains("successfully") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Business Info Section
    
    var businessInfoSection: some View {
        HStack(spacing: 12) {
            if let firstPhotoURL = business.photoURLs.first,
               let url = URL(string: firstPhotoURL) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipped()
                        .cornerRadius(AppRadius.md)
                } placeholder: {
                    ZStack {
                        AppColors.surface
                        ProgressView()
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(AppRadius.md)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(business.name)
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(business.category)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
    }
    
    // MARK: - Rating Section
    
    var ratingSection: some View {
        VStack(spacing: AppSpacing.md) {
            Text("Your Rating")
                .font(AppFonts.title3)
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                ForEach(1...5, id: \.self) { index in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            rating = index
                        }
                    }) {
                        Image(systemName: index <= rating ? "star.fill" : "star")
                            .font(.system(size: 40))
                            .foregroundColor(index <= rating ? AppColors.starYellow : AppColors.textTertiary)
                    }
                    .scaleEffect(index <= rating ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: rating)
                }
            }
            .padding(.vertical, AppSpacing.sm)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
    }
    
    // MARK: - Comment Section
    
    var commentSection: some View {
        VStack(spacing: AppSpacing.md) {
            Text("Your Review")
                .font(AppFonts.title3)
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ZStack(alignment: .topLeading) {
                if comment.isEmpty {
                    Text("Share your experience with this business...")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                }
                
                TextEditor(text: $comment)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(minHeight: 150)
                    .padding(8)
                    .scrollContentBackground(.hidden)
            }
            .background(AppColors.surface)
            .cornerRadius(AppRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Submit Button
    
    var submitButton: some View {
        Button(action: submitReview) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("Submit Review")
                }
            }
            .font(AppFonts.bodyBold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(comment.isEmpty ? AppColors.textTertiary : AppColors.primary)
            .cornerRadius(AppRadius.md)
            .shadow(color: comment.isEmpty ? Color.clear : AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(comment.isEmpty || isSubmitting)
    }
    
    // MARK: - Submit Review
    
    func submitReview() {
        guard let userId = Auth.auth().currentUser?.uid else {
            alertMessage = "You must be logged in to submit a review."
            showingAlert = true
            return
        }
        
        guard let businessId = business.id else {
            alertMessage = "Unable to submit review. Please try again."
            showingAlert = true
            return
        }
        
        guard !comment.isEmpty else {
            alertMessage = "Please write a review comment."
            showingAlert = true
            return
        }
        
        // Get user info
        guard let user = Auth.auth().currentUser,
              let userName = user.displayName,
              let userEmail = user.email else {
            alertMessage = "Unable to get user information."
            showingAlert = true
            return
        }
        
        isSubmitting = true
        
        let review = Review(
            businessId: businessId,
            userId: userId,
            userName: userName,
            userEmail: userEmail,
            rating: Double(rating),
            comment: comment
        )
        
        reviewViewModel.addReview(review) { success, message in
            isSubmitting = false
            alertMessage = message
            showingAlert = true
        }
    }
}
