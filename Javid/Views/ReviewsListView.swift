import SwiftUI
import FirebaseAuth

struct ReviewsListView: View {
    @ObservedObject var reviewViewModel: ReviewViewModel
    @ObservedObject var authViewModel: AuthViewModel
    
    let business: Business
    let isOwner: Bool
    
    @State private var showingAddReview = false
    @State private var showingResponseSheet = false
    @State private var showingLoginPrompt = false
    @State private var selectedReview: Review?
    @State private var ownerResponse = ""
    
    var userReview: Review? {
        guard let userId = authViewModel.currentUser?.uid else { return nil }
        return reviewViewModel.reviews.first { $0.userId == userId }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Reviews (\(reviewViewModel.reviews.count))")
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                if !isOwner {
                    if authViewModel.isLoggedIn {
                        Button(action: {
                            showingAddReview = true
                        }) {
                            HStack {
                                Image(systemName: userReview == nil ? "plus.circle.fill" : "pencil.circle.fill")
                                Text(userReview == nil ? "Add Review" : "Edit Review")
                            }
                            .font(.subheadline)
                        }
                    } else {
                        Button(action: {
                            showingLoginPrompt = true
                        }) {
                            HStack {
                                Image(systemName: "person.circle")
                                Text("Login to Review")
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }
            .padding()
            
            Divider()
            
            // Reviews List
            if reviewViewModel.isLoading && reviewViewModel.reviews.isEmpty {
                ProgressView("Loading reviews...")
                    .padding()
            } else if reviewViewModel.reviews.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star.bubble")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No reviews yet")
                        .font(.headline)
                        .foregroundColor(.gray)
                    if !isOwner {
                        Text(authViewModel.isLoggedIn ? "Be the first to review!" : "Sign in to be the first to review!")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(reviewViewModel.reviews) { review in
                            ReviewCardView(
                                review: review,
                                isOwner: isOwner,
                                isUserReview: review.userId == authViewModel.currentUser?.uid,
                                onDelete: {
                                    deleteReview(review)
                                },
                                onAddResponse: {
                                    selectedReview = review
                                    ownerResponse = ""
                                    showingResponseSheet = true
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingAddReview) {
            if let existingReview = userReview {
                EditReviewView(
                    business: business,
                    reviewViewModel: reviewViewModel,
                    existingReview: existingReview
                )
            } else {
                AddReviewView(
                    business: business,
                    reviewViewModel: reviewViewModel
                )
            }
        }
        .sheet(isPresented: $showingResponseSheet) {
            if let review = selectedReview {
                OwnerResponseView(
                    review: review,
                    reviewViewModel: reviewViewModel,
                    response: $ownerResponse
                )
            }
        }
        .alert("Login Required", isPresented: $showingLoginPrompt) {
            Button("Cancel", role: .cancel) { }
            Button("OK") { }
        } message: {
            Text("Please sign in to write a review. Go to Profile tab to login.")
        }
        .onAppear {
            reviewViewModel.fetchReviews(for: business.id ?? "")
        }
    }
    
    func deleteReview(_ review: Review) {
        reviewViewModel.deleteReview(review) { success, message in
            print(message)
        }
    }
}

struct ReviewCardView: View {
    let review: Review
    let isOwner: Bool
    let isUserReview: Bool
    let onDelete: () -> Void
    let onAddResponse: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info and rating
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(review.userName)
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: Double(star) <= review.rating ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(Double(star) <= review.rating ? .yellow : .gray)
                        }
                        
                        Text(review.createdAt, style: .date)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                if isUserReview && !isOwner {
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
                
                if isOwner && !review.isOwnerResponse {
                    Button(action: onAddResponse) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Comment
            Text(review.comment)
                .font(.body)
                .foregroundColor(.primary)
            
            // Owner Response
            if review.isOwnerResponse, let response = review.ownerResponse {
                Divider()
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "storefront.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Owner Response")
                                .font(.subheadline)
                                .bold()
                            
                            if let responseDate = review.ownerResponseDate {
                                Text(responseDate, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Text(response)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .alert("Delete Review", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete your review?")
        }
    }
}

struct OwnerResponseView: View {
    @Environment(\.dismiss) var dismiss
    let review: Review
    @ObservedObject var reviewViewModel: ReviewViewModel
    @Binding var response: String
    
    @State private var isSaving = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Responding to")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(review.userName)
                                .font(.headline)
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: Double(star) <= review.rating ? "star.fill" : "star")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                        Text(review.comment)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Your Response")) {
                    TextEditor(text: $response)
                        .frame(height: 150)
                }
                
                Section {
                    Button(action: submitResponse) {
                        if isSaving {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("Submit Response")
                                    .bold()
                                Spacer()
                            }
                        }
                    }
                    .disabled(isSaving || response.isEmpty)
                }
            }
            .navigationTitle("Add Response")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Message", isPresented: $showingAlert) {
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
    
    func submitResponse() {
        guard !response.isEmpty else {
            alertMessage = "❌ Please write a response"
            showingAlert = true
            return
        }
        
        isSaving = true
        
        reviewViewModel.addOwnerResponse(to: review, response: response) { success, message in
            isSaving = false
            alertMessage = message
            showingAlert = true
        }
    }
}
