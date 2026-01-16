import SwiftUI
import FirebaseAuth
import UniformTypeIdentifiers

struct ApplyToJobView: View {
    let job: Job
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var applicationVM: JobApplicationViewModel
    @StateObject private var profileVM = JobSeekerProfileViewModel()
    
    @State private var coverLetter = ""
    @State private var phone = ""
    @State private var resumeURL = ""
    @State private var portfolioURL = ""
    @State private var answers: [String] = []
    @State private var selectedResumeFile: URL?
    @State private var showingDocumentPicker = false
    @State private var isSubmitting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // Job Info Header
                        jobInfoHeader
                        
                        // Application Form
                        VStack(spacing: AppSpacing.md) {
                            // Personal Info
                            personalInfoSection
                            
                            // Resume Upload
                            resumeSection
                            
                            // Portfolio (Optional)
                            portfolioSection
                            
                            // Cover Letter
                            coverLetterSection
                            
                            // Custom Questions
                            if !job.questions.isEmpty {
                                customQuestionsSection
                            }
                            
                            // Submit Button
                            submitButton
                        }
                        .padding(AppSpacing.md)
                    }
                }
            }
            .navigationTitle("Apply for Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker(selectedURL: $selectedResumeFile)
            }
            .alert(isSuccess ? "Success" : "Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {
                    if isSuccess {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadProfileData()
                initializeAnswers()
            }
        }
    }
    
    // MARK: - Job Info Header
    var jobInfoHeader: some View {
        HStack(spacing: 12) {
            // Company Logo
            if let logoURL = job.companyLogo, let url = URL(string: logoURL) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    ZStack {
                        AppColors.surface
                        ProgressView()
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                ZStack {
                    Color(hex: job.category.color).opacity(0.2)
                    Image(systemName: "building.2.fill")
                        .foregroundColor(Color(hex: job.category.color))
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(job.title)
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                
                Text(job.company)
                    .font(AppFonts.callout)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - Personal Info Section
    var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Personal Information")
                .font(AppFonts.title3)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.sm) {
                // Name (pre-filled from profile)
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 20)
                    Text(Auth.auth().currentUser?.displayName ?? "Your Name")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding()
                .background(AppColors.surface)
                .cornerRadius(AppRadius.md)
                
                // Email (pre-filled from profile)
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 20)
                    Text(Auth.auth().currentUser?.email ?? "your.email@example.com")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding()
                .background(AppColors.surface)
                .cornerRadius(AppRadius.md)
                
                // Phone
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 20)
                    TextField("Phone Number", text: $phone)
                        .font(AppFonts.body)
                        .keyboardType(.phonePad)
                }
                .padding()
                .background(AppColors.surface)
                .cornerRadius(AppRadius.md)
            }
        }
    }
    
    // MARK: - Resume Section
    var resumeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Resume *")
                .font(AppFonts.title3)
                .foregroundColor(AppColors.textPrimary)
            
            if !resumeURL.isEmpty || selectedResumeFile != nil {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(AppColors.primary)
                            Text(selectedResumeFile?.lastPathComponent ?? "Resume.pdf")
                                .font(AppFonts.callout)
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                        }
                        
                        if !resumeURL.isEmpty {
                            Text("From profile")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showingDocumentPicker = true
                    }) {
                        Text("Change")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.primary)
                    }
                }
                .padding()
                .background(AppColors.surface)
                .cornerRadius(AppRadius.md)
            } else {
                Button(action: {
                    showingDocumentPicker = true
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(AppColors.primary)
                        
                        VStack(spacing: 4) {
                            Text("Upload Resume")
                                .font(AppFonts.bodyBold)
                                .foregroundColor(AppColors.primary)
                            
                            Text("PDF, DOC, or DOCX (Max 10MB)")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xl)
                    .background(AppColors.surface)
                    .cornerRadius(AppRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(AppColors.primary, style: StrokeStyle(lineWidth: 2, dash: [5]))
                    )
                }
            }
        }
    }
    
    // MARK: - Portfolio Section
    var portfolioSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Portfolio (Optional)")
                .font(AppFonts.title3)
                .foregroundColor(AppColors.textPrimary)
            
            HStack {
                Image(systemName: "link")
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 20)
                TextField("https://yourportfolio.com", text: $portfolioURL)
                    .font(AppFonts.body)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            }
            .padding()
            .background(AppColors.surface)
            .cornerRadius(AppRadius.md)
        }
    }
    
    // MARK: - Cover Letter Section
    var coverLetterSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Cover Letter *")
                .font(AppFonts.title3)
                .foregroundColor(AppColors.textPrimary)
            
            ZStack(alignment: .topLeading) {
                if coverLetter.isEmpty {
                    Text("Tell us why you're a great fit for this position...\n\nHighlight your relevant experience, skills, and what excites you about this opportunity.")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                }
                
                TextEditor(text: $coverLetter)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(minHeight: 200)
                    .padding(8)
                    .scrollContentBackground(.hidden)
            }
            .background(AppColors.surface)
            .cornerRadius(AppRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(AppColors.border, lineWidth: 1)
            )
            
            HStack {
                Spacer()
                Text("\(coverLetter.count) / 2000 characters")
                    .font(AppFonts.caption)
                    .foregroundColor(coverLetter.count > 2000 ? AppColors.error : AppColors.textSecondary)
            }
        }
    }
    
    // MARK: - Custom Questions Section
    var customQuestionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Additional Questions")
                .font(AppFonts.title3)
                .foregroundColor(AppColors.textPrimary)
            
            ForEach(Array(job.questions.enumerated()), id: \.offset) { index, question in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(index + 1). \(question)")
                        .font(AppFonts.callout)
                        .foregroundColor(AppColors.textPrimary)
                    
                    TextField("Your answer...", text: Binding(
                        get: { answers.indices.contains(index) ? answers[index] : "" },
                        set: { newValue in
                            if answers.indices.contains(index) {
                                answers[index] = newValue
                            }
                        }
                    ), axis: .vertical)
                    .font(AppFonts.body)
                    .padding()
                    .background(AppColors.surface)
                    .cornerRadius(AppRadius.md)
                    .lineLimit(3...5)
                }
            }
        }
    }
    
    // MARK: - Submit Button
    var submitButton: some View {
        Button(action: submitApplication) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("Submit Application")
                }
            }
            .font(AppFonts.bodyBold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isFormValid ? AppColors.primary : AppColors.textTertiary)
            .cornerRadius(AppRadius.md)
            .shadow(color: isFormValid ? AppColors.primary.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
        }
        .disabled(!isFormValid || isSubmitting)
        .padding(.top, AppSpacing.md)
    }
    
    // MARK: - Helper Functions
    var isFormValid: Bool {
        !phone.isEmpty &&
        (!resumeURL.isEmpty || selectedResumeFile != nil) &&
        !coverLetter.isEmpty &&
        coverLetter.count <= 2000 &&
        (job.questions.isEmpty || answers.filter { !$0.isEmpty }.count == job.questions.count)
    }
    
    func loadProfileData() {
        profileVM.fetchProfile()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let profile = profileVM.profile {
                phone = profile.phone
                resumeURL = profile.resumeURL ?? ""
                portfolioURL = profile.portfolioURL ?? ""
            }
        }
    }
    
    func initializeAnswers() {
        answers = Array(repeating: "", count: job.questions.count)
    }
    
    func submitApplication() {
        guard let userId = Auth.auth().currentUser?.uid,
              let userName = Auth.auth().currentUser?.displayName,
              let userEmail = Auth.auth().currentUser?.email,
              let jobId = job.id else {
            alertMessage = "Unable to submit application. Please try again."
            showingAlert = true
            return
        }
        
        isSubmitting = true
        
        // If user selected a new resume, upload it first
        if let resumeFile = selectedResumeFile {
            DocumentManager.shared.uploadDocument(resumeFile) { result in
                switch result {
                case .success(let url):
                    submitWithResumeURL(url, userId: userId, userName: userName, userEmail: userEmail, jobId: jobId)
                case .failure(let error):
                    isSubmitting = false
                    isSuccess = false
                    alertMessage = "Failed to upload resume: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        } else {
            // Use existing resume URL from profile
            submitWithResumeURL(resumeURL, userId: userId, userName: userName, userEmail: userEmail, jobId: jobId)
        }
    }
    
    func submitWithResumeURL(_ resumeURL: String, userId: String, userName: String, userEmail: String, jobId: String) {
        let application = JobApplication(
            jobId: jobId,
            jobTitle: job.title,
            company: job.company,
            applicantId: userId,
            applicantName: userName,
            applicantEmail: userEmail,
            applicantPhone: phone,
            coverLetter: coverLetter,
            resumeURL: resumeURL,
            portfolioURL: portfolioURL.isEmpty ? nil : portfolioURL,
            answers: answers
        )
        
        applicationVM.submitApplication(application) { success, message in
            isSubmitting = false
            isSuccess = success
            alertMessage = message
            showingAlert = true
        }
    }
}

// MARK: - Document Picker
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            UTType.pdf,
            UTType(filenameExtension: "doc")!,
            UTType(filenameExtension: "docx")!
        ], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Validate document
            let validation = DocumentManager.shared.validateDocument(url)
            if validation.isValid {
                parent.selectedURL = url
            } else {
                print("❌ Invalid document: \(validation.error ?? "Unknown error")")
            }
            
            parent.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}
