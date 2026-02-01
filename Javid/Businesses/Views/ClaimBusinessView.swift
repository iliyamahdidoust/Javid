import SwiftUI
import PhotosUI

struct ClaimBusinessView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ClaimBusinessViewModel()
    @ObservedObject var authViewModel: AuthViewModel
    
    let business: Business
    
    @State private var additionalNotes = ""
    @State private var uploadedDocuments: [ClaimVerificationDocument] = []
    @State private var showingDocumentPicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedDocumentType: ClaimVerificationDocument.DocumentType = .businessLicense
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection
                    
                    // Business Info
                    businessInfoSection
                    
                    // Requirements
                    requirementsSection
                    
                    // Document Upload
                    documentUploadSection
                    
                    // Uploaded Documents
                    if !uploadedDocuments.isEmpty {
                        uploadedDocumentsSection
                    }
                    
                    // Additional Notes
                    notesSection
                    
                    // Submit Button
                    submitButton
                }
                .padding()
            }
            .navigationTitle("Claim Business")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .alert("Message", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {
                    if showingSuccess {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .overlay {
                if viewModel.isUploadingDocument {
                    uploadProgressOverlay
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "building.2.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Claim Ownership")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text("Verify that you own or manage this business to gain access to the owner dashboard.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Business Info Section
    
    private var businessInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Business Details")
                .font(.headline)
            
            HStack(spacing: 12) {
                if let firstPhoto = business.photoURLs.first,
                   let photoURL = URL(string: firstPhoto) {
                    AsyncImage(url: photoURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "building.2")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(business.name)
                        .font(.headline)
                    
                    Text(business.category)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(business.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Requirements Section
    
    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verification Requirements")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                requirementRow(
                    icon: "doc.text.fill",
                    title: "Verification Documents",
                    description: "Upload at least one document proving ownership"
                )
                
                requirementRow(
                    icon: "checkmark.seal.fill",
                    title: "Admin Review",
                    description: "Your claim will be reviewed by our team within 2-3 business days"
                )
                
                requirementRow(
                    icon: "bell.fill",
                    title: "Notification",
                    description: "You'll be notified once your claim is approved or if additional info is needed"
                )
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private func requirementRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Document Upload Section
    
    private var documentUploadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upload Verification Documents")
                .font(.headline)
            
            Text("Accepted documents: Business license, Tax ID, Utility bill, Government ID, or proof of ownership")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Document Type Picker
            Picker("Document Type", selection: $selectedDocumentType) {
                ForEach(ClaimVerificationDocument.DocumentType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.icon)
                        .tag(type)
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Photo Picker
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text("Select Document Photo")
                            .fontWeight(.semibold)
                        Text("Choose from your photo library")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .onChange(of: selectedPhoto) { newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        uploadDocument(uiImage)
                    }
                }
            }
        }
    }
    
    // MARK: - Uploaded Documents Section
    
    private var uploadedDocumentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Uploaded Documents (\(uploadedDocuments.count))")
                    .font(.headline)
                
                Spacer()
                
                Text("✓ Ready")
                    .font(.caption)
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
            }
            
            ForEach(uploadedDocuments) { document in
                documentRow(document)
            }
        }
    }
    
    private func documentRow(_ document: ClaimVerificationDocument) -> some View {
        HStack(spacing: 12) {
            Image(systemName: document.documentType.icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.documentType.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(document.formattedFileSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                uploadedDocuments.removeAll { $0.id == document.id }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Additional Information (Optional)")
                .font(.headline)
            
            TextEditor(text: $additionalNotes)
                .frame(height: 120)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            
            Text("Provide any additional details that might help verify your ownership")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Submit Button
    
    private var submitButton: some View {
        Button(action: submitClaim) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("Submit Claim")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(uploadedDocuments.isEmpty ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(uploadedDocuments.isEmpty || viewModel.isLoading)
    }
    
    // MARK: - Upload Progress Overlay
    
    private var uploadProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView(value: viewModel.uploadProgress)
                    .progressViewStyle(.linear)
                    .tint(.white)
                    .frame(width: 200)
                
                Text("Uploading document...")
                    .foregroundColor(.white)
                    .font(.subheadline)
            }
            .padding(24)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Actions
    
    private func uploadDocument(_ image: UIImage) {
        viewModel.uploadVerificationDocument(image, documentType: selectedDocumentType) { document in
            if let document = document {
                uploadedDocuments.append(document)
            }
        }
    }
    
    private func submitClaim() {
        // Convert Firebase User to UserProfile
        guard let currentUser = authViewModel.currentUser else {
            alertMessage = "You must be logged in to claim a business"
            showingAlert = true
            return
        }
        
        // Fetch the UserProfile from Firestore or create one from currentUser
        // Option 1: If you have a userProfile property in AuthViewModel, use it
        guard let userProfile = authViewModel.userProfile else {
            alertMessage = "Unable to load user profile. Please try again."
            showingAlert = true
            return
        }
        
        viewModel.submitClaim(
            business: business,
            userProfile: userProfile,
            documents: uploadedDocuments,
            additionalNotes: additionalNotes.isEmpty ? nil : additionalNotes
        ) { success, message in
            showingSuccess = success
            alertMessage = message
            showingAlert = true
        }
    }
}

// MARK: - Preview

struct ClaimBusinessView_Previews: PreviewProvider {
    static var previews: some View {
        ClaimBusinessView(
            authViewModel: AuthViewModel(),
            business: Business(
                name: "Sample Restaurant",
                category: "Restaurant",
                description: "Great food",
                phone: "123-456-7890",
                address: "123 Main St",
                city: "New York",
                country: "USA",
                latitude: 40.7128,
                longitude: -74.0060,
                ownerId: "admin123",
                isClaimable: true
            )
        )
    }
}
