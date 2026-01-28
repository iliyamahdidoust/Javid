import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var phoneNumber: String = ""
    @State private var bio: String = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        // Profile Image Section
                        profileImageSection
                        
                        // Form Fields
                        VStack(spacing: AppSpacing.lg) {
                            formField(
                                title: "Display Name",
                                text: $displayName,
                                placeholder: "Enter your name",
                                icon: "person.fill"
                            )
                            
                            formField(
                                title: "Email",
                                text: $email,
                                placeholder: "your.email@example.com",
                                icon: "envelope.fill",
                                disabled: true
                            )
                            
                            formField(
                                title: "Phone Number",
                                text: $phoneNumber,
                                placeholder: "+1 (555) 000-0000",
                                icon: "phone.fill",
                                keyboardType: .phonePad
                            )
                            
                            // Bio Text Editor
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Label("Bio", systemImage: "text.alignleft")
                                    .font(AppFonts.callout)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                TextEditor(text: $bio)
                                    .frame(height: 100)
                                    .padding(AppSpacing.sm)
                                    .background(AppColors.surface)
                                    .cornerRadius(AppRadius.md)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppRadius.md)
                                            .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        
                        // Save Button
                        Button(action: saveProfile) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Save Changes")
                                        .fontWeight(.semibold)
                                }
                            }
                            .font(AppFonts.body)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        AppColors.primary,
                                        AppColors.primary.opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(AppRadius.lg)
                            .shadow(color: AppColors.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .disabled(isLoading)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.md)
                    }
                    .padding(.vertical, AppSpacing.lg)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .onAppear(perform: loadUserData)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Profile Image Section
    
    private var profileImageSection: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack(alignment: .bottomTrailing) {
                // Profile Image
                Group {
                    if let selectedImageData,
                       let uiImage = UIImage(data: selectedImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else if let profileImageURL = authViewModel.userProfile?.profileImageURL,
                              let url = URL(string: profileImageURL) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } placeholder: {
                            profilePlaceholder
                        }
                    } else {
                        profilePlaceholder
                    }
                }
                .overlay(
                    Circle()
                        .stroke(AppColors.primary, lineWidth: 3)
                )
                
                // Edit Button
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(AppColors.primary)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                }
                .onChange(of: selectedImage) { newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self) {
                            selectedImageData = data
                        }
                    }
                }
            }
            
            Text("Tap to change photo")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    private var profilePlaceholder: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            AppColors.primary.opacity(0.8),
                            AppColors.primary
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
            
            Text(String(displayName.prefix(1)).uppercased())
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Form Field
    
    private func formField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        icon: String,
        disabled: Bool = false,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label(title, systemImage: icon)
                .font(AppFonts.callout)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .disabled(disabled)
                .padding(AppSpacing.md)
                .background(disabled ? AppColors.surface.opacity(0.5) : AppColors.surface)
                .cornerRadius(AppRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Load User Data
    
    private func loadUserData() {
        if let profile = authViewModel.userProfile {
            displayName = profile.displayName ?? ""
            email = profile.email ?? ""
            phoneNumber = profile.phoneNumber ?? ""
            bio = profile.bio ?? ""
        }
    }
    
    // MARK: - Save Profile
    
    private func saveProfile() {
        isLoading = true
        
        Task {
            do {
                // Upload image if changed
                var imageURL: String? = authViewModel.userProfile?.profileImageURL
                if let imageData = selectedImageData {
                    imageURL = try await authViewModel.uploadProfileImage(imageData)
                }
                
                // Update profile
                let success = await authViewModel.updateUserProfile(
                    displayName: displayName,
                    phoneNumber: phoneNumber,
                    bio: bio,
                    profileImageURL: imageURL
                )
                
                isLoading = false
                
                if success {
                    dismiss()
                } else {
                    errorMessage = "Failed to update profile"
                    showError = true
                }
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
