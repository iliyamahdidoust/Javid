import SwiftUI
import PhotosUI

struct VerificationSubmitView: View {
    @ObservedObject var viewModel: EmployerProfileViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var businessRegDocument: URL?
    @State private var taxIDDocument: URL?
    @State private var proofDocument: URL?
    @State private var additionalDocuments: [URL] = []
    @State private var verificationNotes = ""
    
    @State private var showingBusinessPicker = false
    @State private var showingTaxPicker = false
    @State private var showingProofPicker = false
    @State private var showingAdditionalPicker = false
    
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var canSubmit: Bool {
        businessRegDocument != nil && taxIDDocument != nil && !verificationNotes.isEmpty
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Employer Verification")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Get verified to build trust with job seekers")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Required Documents
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Required Documents")
                            .font(.headline)
                        
                        // Business Registration
                        DocumentUploadCard(
                            title: "Business Registration",
                            description: "Certificate of incorporation or business registration",
                            icon: "building.2.fill",
                            document: businessRegDocument,
                            isRequired: true,
                            onTap: { showingBusinessPicker = true },
                            onRemove: { businessRegDocument = nil }
                        )
                        
                        // Tax ID
                        DocumentUploadCard(
                            title: "Tax ID / EIN",
                            description: "Tax identification number or EIN documentation",
                            icon: "doc.text.fill",
                            document: taxIDDocument,
                            isRequired: true,
                            onTap: { showingTaxPicker = true },
                            onRemove: { taxIDDocument = nil }
                        )
                    }
                    
                    // Optional Documents
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Optional Documents")
                            .font(.headline)
                        
                        // Proof of Ownership
                        DocumentUploadCard(
                            title: "Proof of Ownership",
                            description: "Document proving business ownership (optional)",
                            icon: "checkmark.shield.fill",
                            document: proofDocument,
                            isRequired: false,
                            onTap: { showingProofPicker = true },
                            onRemove: { proofDocument = nil }
                        )
                    }
                    
                    // Additional Notes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Verification Notes")
                            .font(.headline)
                        
                        Text("Tell us about your company and why you should be verified")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $verificationNotes)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        
                        Text("\(verificationNotes.count)/500 characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Info Box
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Review Process")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text("Our team will review your documents within 2-3 business days. You'll receive an email once the review is complete.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Upload Progress
                    if isUploading {
                        VStack(spacing: 8) {
                            ProgressView(value: uploadProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                            
                            Text("Uploading documents... \(Int(uploadProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    
                    // Submit Button
                    Button(action: submitVerification) {
                        HStack {
                            if isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isUploading ? "Submitting..." : "Submit for Verification")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSubmit && !isUploading ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canSubmit || isUploading)
                }
                .padding()
            }
            .navigationTitle("Get Verified")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingBusinessPicker,
                allowedContentTypes: [.pdf, .png, .jpeg],
                allowsMultipleSelection: false
            ) { result in
                handleDocumentSelection(result, for: .businessRegistration)
            }
            .fileImporter(
                isPresented: $showingTaxPicker,
                allowedContentTypes: [.pdf, .png, .jpeg],
                allowsMultipleSelection: false
            ) { result in
                handleDocumentSelection(result, for: .taxID)
            }
            .fileImporter(
                isPresented: $showingProofPicker,
                allowedContentTypes: [.pdf, .png, .jpeg],
                allowsMultipleSelection: false
            ) { result in
                handleDocumentSelection(result, for: .proofOfOwnership)
            }
            .alert("Success!", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your verification request has been submitted successfully. We'll review it within 2-3 business days.")
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func handleDocumentSelection(_ result: Result<[URL], Error>, for type: VerificationDocumentType) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            
            switch type {
            case .businessRegistration:
                businessRegDocument = url
            case .taxID:
                taxIDDocument = url
            case .proofOfOwnership:
                proofDocument = url
            case .other:
                additionalDocuments.append(url)
            }
        } catch {
            errorMessage = "Failed to select document: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
    
    private func submitVerification() {
        guard canSubmit else { return }
        
        isUploading = true
        uploadProgress = 0
        
        var documentsToUpload: [URL] = []
        if let businessReg = businessRegDocument {
            documentsToUpload.append(businessReg)
        }
        if let taxID = taxIDDocument {
            documentsToUpload.append(taxID)
        }
        if let proof = proofDocument {
            documentsToUpload.append(proof)
        }
        documentsToUpload.append(contentsOf: additionalDocuments)
        
        // Upload documents
        Task {
            do {
                var uploadedURLs: [String] = []
                let totalDocs = documentsToUpload.count
                
                for (index, docURL) in documentsToUpload.enumerated() {
                    // Validate document first
                    let validation = DocumentManager.shared.validateDocument(docURL)
                    if !validation.isValid {
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: validation.error ?? "Invalid document"])
                    }
                    
                    // Upload using DocumentManager
                    let downloadURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                        DocumentManager.shared.uploadDocument(docURL) { result in
                            continuation.resume(with: result)
                        }
                    }
                    
                    uploadedURLs.append(downloadURL)
                    
                    await MainActor.run {
                        uploadProgress = Double(index + 1) / Double(totalDocs)
                    }
                }
                
                // Submit verification
                await viewModel.submitVerification(
                    documents: uploadedURLs,
                    notes: verificationNotes
                )
                
                await MainActor.run {
                    isUploading = false
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    errorMessage = "Failed to upload documents: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }
}

struct DocumentUploadCard: View {
    let title: String
    let description: String
    let icon: String
    let document: URL?
    let isRequired: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        if isRequired {
                            Text("Required")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let doc = document {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                    }
                }
            }
            
            if let doc = document {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(doc.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else {
                Button(action: onTap) {
                    HStack {
                        Image(systemName: "arrow.up.doc.fill")
                        Text("Upload Document")
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
