import SwiftUI
import PhotosUI

struct EditEmployerProfileView: View {
    @ObservedObject var viewModel: EmployerProfileViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var companyName = ""
    @State private var industry = ""
    @State private var companySize: CompanySize = .small
    @State private var description = ""
    @State private var website = ""
    @State private var location = ""
    @State private var contactEmail = ""
    @State private var contactPhone = ""
    
    @State private var selectedImage: PhotosPickerItem?
    @State private var logoImage: UIImage?
    @State private var isUploading = false
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var isCreatingNew: Bool {
        viewModel.employerProfile == nil
    }
    
    var canSave: Bool {
        !companyName.isEmpty &&
        !industry.isEmpty &&
        !description.isEmpty &&
        !website.isEmpty &&
        !location.isEmpty &&
        !contactEmail.isEmpty &&
        !contactPhone.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Logo Section
                Section {
                    VStack(spacing: 16) {
                        if let logoImage = logoImage {
                            Image(uiImage: logoImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        } else if let logoURL = viewModel.employerProfile?.logoURL {
                            AsyncImage(url: URL(string: logoURL)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        } else {
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                                .frame(width: 100, height: 100)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        
                        PhotosPicker(selection: $selectedImage, matching: .images) {
                            Text(logoImage != nil || viewModel.employerProfile?.logoURL != nil ? "Change Logo" : "Upload Logo")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity)
                } header: {
                    Text("Company Logo")
                }
                
                // Basic Information
                Section {
                    TextField("Company Name", text: $companyName)
                    TextField("Industry", text: $industry)
                    
                    Picker("Company Size", selection: $companySize) {
                        ForEach(CompanySize.allCases, id: \.self) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                } header: {
                    Text("Basic Information")
                }
                
                // Description
                Section {
                    TextEditor(text: $description)
                        .frame(height: 100)
                    
                    Text("\(description.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Company Description")
                } footer: {
                    Text("Tell job seekers about your company, culture, and what makes you unique.")
                }
                
                // Location & Website
                Section {
                    TextField("Location", text: $location)
                    TextField("Website", text: $website)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                } header: {
                    Text("Location & Website")
                }
                
                // Contact Information
                Section {
                    TextField("Contact Email", text: $contactEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    
                    TextField("Contact Phone", text: $contactPhone)
                        .keyboardType(.phonePad)
                } header: {
                    Text("Contact Information")
                } footer: {
                    Text("This information will be visible to job applicants.")
                }
                
                // Save Button
                Section {
                    Button(action: saveProfile) {
                        HStack {
                            if isSaving {
                                ProgressView()
                            }
                            Text(isSaving ? "Saving..." : (isCreatingNew ? "Create Profile" : "Save Changes"))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(canSave && !isSaving ? .blue : .gray)
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .navigationTitle(isCreatingNew ? "Create Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadExistingData()
            }
            .onChange(of: selectedImage) { newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        logoImage = uiImage
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func loadExistingData() {
        guard let profile = viewModel.employerProfile else { return }
        
        companyName = profile.companyName
        industry = profile.industry
        companySize = profile.companySize
        description = profile.description
        website = profile.website
        location = profile.location
        contactEmail = profile.contactEmail
        contactPhone = profile.contactPhone
    }
    
    private func saveProfile() {
        guard canSave else { return }
        
        isSaving = true
        
        Task {
            do {
                // Upload logo if changed
                if let logoImage = logoImage,
                   let imageData = logoImage.jpegData(compressionQuality: 0.7) {
                    _ = try await viewModel.uploadLogo(imageData: imageData)
                }
                
                // Save profile
                if isCreatingNew {
                    try await viewModel.createEmployerProfile(
                        companyName: companyName,
                        industry: industry,
                        companySize: companySize,
                        description: description,
                        website: website,
                        location: location,
                        contactEmail: contactEmail,
                        contactPhone: contactPhone
                    )
                } else {
                    try await viewModel.updateEmployerProfile(
                        companyName: companyName,
                        industry: industry,
                        companySize: companySize,
                        description: description,
                        website: website,
                        location: location,
                        contactEmail: contactEmail,
                        contactPhone: contactPhone
                    )
                }
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}
