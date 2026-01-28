import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Combine
import LocalAuthentication

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    @Published var userProfile: UserProfile?
    @Published var errorMessage = ""
    @Published var isLoading = false // NEW: For loading states
    
    private let db = Firestore.firestore()
    
    init() {
        // Check if user is already logged in
        if let user = Auth.auth().currentUser {
            self.isLoggedIn = true
            self.currentUser = user
            fetchUserProfile(uid: user.uid)
        }
    }
    
    func signUp(email: String, password: String, name: String, isBusiness: Bool, completion: @escaping (Bool, String) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error as NSError? {
                let errorMessage = self?.getReadableError(error: error, isSignUp: true) ?? "Unknown error"
                completion(false, errorMessage)
                return
            }
            
            guard let user = result?.user else {
                completion(false, "Unknown error occurred")
                return
            }
            
            // Update display name
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = name
            changeRequest.commitChanges { error in
                if let error = error {
                    completion(false, "Account created but failed to save name: \(error.localizedDescription)")
                    return
                }
                
                // Save user profile to Firestore
                let userProfile = UserProfile(
                    uid: user.uid,
                    email: email,
                    name: name,
                    isBusinessOwner: isBusiness
                )
                
                self?.saveUserProfile(userProfile) { success, message in
                    if success {
                        self?.currentUser = user
                        self?.userProfile = userProfile
                        self?.isLoggedIn = true
                        
                        // Save credentials for biometric login
                        self?.saveCredentialsToKeychain(email: email, password: password)
                        
                        completion(true, "✅ Account created successfully!")
                    } else {
                        completion(false, "Account created but failed to save profile: \(message)")
                    }
                }
            }
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Bool, String) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            if let error = error as NSError? {
                let errorMessage = self?.getReadableError(error: error, isSignUp: false) ?? "Unknown error"
                completion(false, errorMessage)
                return
            }
            
            guard let user = result?.user else {
                completion(false, "Unknown error occurred")
                return
            }
            
            self?.currentUser = user
            self?.fetchUserProfile(uid: user.uid)
            self?.isLoggedIn = true
            
            // Save credentials for biometric login
            self?.saveCredentialsToKeychain(email: email, password: password)
            
            completion(true, "✅ Login successful!")
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.isLoggedIn = false
            self.currentUser = nil
            self.userProfile = nil
            
            // Optionally remove credentials from keychain on sign out
            // removeCredentialsFromKeychain()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func resetPassword(email: String, completion: @escaping (Bool, String) -> Void) {
        guard !email.isEmpty else {
            completion(false, "❌ Please enter your email address")
            return
        }
        
        guard email.contains("@") && email.contains(".") else {
            completion(false, "❌ Please enter a valid email address")
            return
        }
        
        Auth.auth().sendPasswordReset(withEmail: email.trimmingCharacters(in: .whitespaces)) { error in
            if let error = error as NSError? {
                let errorMessage = self.getReadableError(error: error, isSignUp: false)
                completion(false, errorMessage)
            } else {
                completion(true, "✅ Password reset email sent! Please check your inbox.")
            }
        }
    }
    
    // MARK: - NEW: Profile Management Methods
    
    /// Refresh user profile from Firestore
    @MainActor
    func refreshUserProfile() async {
        guard let userId = currentUser?.uid else { return }
        
        isLoading = true
        
        do {
            let document = try await db.collection("users")
                .document(userId)
                .getDocument()
            
            if let data = document.data() {
                // Update userProfile with all fields
                self.userProfile = UserProfile(
                    uid: userId,
                    email: data["email"] as? String ?? "",
                    name: data["name"] as? String ?? "",
                    phoneNumber: data["phoneNumber"] as? String,
                    bio: data["bio"] as? String,
                    profileImageURL: data["profileImageURL"] as? String,
                    isBusinessOwner: data["isBusinessOwner"] as? Bool ?? false,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                    updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
                )
            }
            
            isLoading = false
        } catch {
            print("Error refreshing user profile: \(error.localizedDescription)")
            isLoading = false
        }
    }
    
    /// Upgrade user to business owner
    func upgradeToBusinessOwner(completion: @escaping (Bool, String) -> Void) async {
        guard let userId = currentUser?.uid else {
            await MainActor.run {
                completion(false, "User not authenticated")
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            try await db.collection("users")
                .document(userId)
                .updateData([
                    "isBusinessOwner": true,
                    "upgradedToBusinessAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ])
            
            // Update local user profile
            await refreshUserProfile()
            
            await MainActor.run {
                isLoading = false
                completion(true, "Successfully upgraded to Business Owner")
            }
        } catch {
            await MainActor.run {
                isLoading = false
                completion(false, "Failed to upgrade: \(error.localizedDescription)")
            }
        }
    }
    
    /// Update user profile information
    func updateUserProfile(
        displayName: String,
        phoneNumber: String,
        bio: String,
        profileImageURL: String?
    ) async -> Bool {
        guard let userId = currentUser?.uid else { return false }
        
        await MainActor.run {
            isLoading = true
        }
        
        var updateData: [String: Any] = [
            "name": displayName,
            "phoneNumber": phoneNumber,
            "bio": bio,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        if let imageURL = profileImageURL {
            updateData["profileImageURL"] = imageURL
        }
        
        do {
            try await db.collection("users")
                .document(userId)
                .updateData(updateData)
            
            // Update Firebase Auth display name
            let changeRequest = currentUser?.createProfileChangeRequest()
            changeRequest?.displayName = displayName
            try await changeRequest?.commitChanges()
            
            // Refresh local profile
            await refreshUserProfile()
            
            await MainActor.run {
                isLoading = false
            }
            
            return true
        } catch {
            print("Error updating profile: \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
            }
            return false
        }
    }
    
    /// Upload profile image to Firebase Storage
    func uploadProfileImage(_ imageData: Data) async throws -> String {
        guard let userId = currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        let storageRef = Storage.storage().reference()
        let imageRef = storageRef.child("profile_images/\(userId)/profile.jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            // Upload the image
            _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
            
            // Get download URL
            let downloadURL = try await imageRef.downloadURL()
            
            await MainActor.run {
                isLoading = false
            }
            
            return downloadURL.absoluteString
        } catch {
            await MainActor.run {
                isLoading = false
            }
            throw error
        }
    }
    
    /// Delete user account
    func deleteAccount(completion: @escaping (Bool, String) -> Void) async {
        guard let userId = currentUser?.uid else {
            await MainActor.run {
                completion(false, "User not authenticated")
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Delete user data from Firestore
            try await db.collection("users")
                .document(userId)
                .delete()
            
            // Delete user's businesses if they're a business owner
            if userProfile?.isBusinessOwner == true {
                let businessesSnapshot = try await db.collection("businesses")
                    .whereField("ownerId", isEqualTo: userId)
                    .getDocuments()
                
                for document in businessesSnapshot.documents {
                    try await document.reference.delete()
                }
            }
            
            // Delete user's favorites
            let favoritesSnapshot = try await db.collection("users")
                .document(userId)
                .collection("favorites")
                .getDocuments()
            
            for document in favoritesSnapshot.documents {
                try await document.reference.delete()
            }
            
            // Delete profile image from Storage
            let storageRef = Storage.storage().reference()
            let imageRef = storageRef.child("profile_images/\(userId)/profile.jpg")
            try? await imageRef.delete()
            
            // Delete Firebase Auth account
            try await currentUser?.delete()
            
            // Remove credentials from keychain
            removeCredentialsFromKeychain()
            
            await MainActor.run {
                self.isLoggedIn = false
                self.currentUser = nil
                self.userProfile = nil
                self.isLoading = false
                completion(true, "Account deleted successfully")
            }
        } catch {
            await MainActor.run {
                isLoading = false
                completion(false, "Failed to delete account: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Biometric Properties
    
    /// Check if biometric authentication is available on the device
    var biometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Get the type of biometric authentication available
    var biometricType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }
    
    /// Human-readable string for the biometric type
    var biometricTypeString: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Biometrics"
        @unknown default:
            return "Biometrics"
        }
    }
    
    /// System icon name for the biometric type
    var biometricIcon: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        case .none:
            return "lock.shield.fill"
        @unknown default:
            return "lock.shield.fill"
        }
    }
    
    // MARK: - Biometric Authentication
    
    /// Authenticate user with biometrics
    func authenticateWithBiometrics(completion: @escaping (Bool, String) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            DispatchQueue.main.async {
                completion(false, error?.localizedDescription ?? "Biometric authentication is not available")
            }
            return
        }
        
        // Attempt to authenticate
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Authenticate to sign in to your account"
        ) { [weak self] success, authError in
            DispatchQueue.main.async {
                if success {
                    // Retrieve stored credentials from keychain
                    self?.signInWithStoredCredentials(completion: completion)
                } else {
                    let message = authError?.localizedDescription ?? "Authentication failed"
                    completion(false, message)
                }
            }
        }
    }
    
    // MARK: - Keychain Helpers
    
    /// Sign in with credentials stored in keychain
    private func signInWithStoredCredentials(completion: @escaping (Bool, String) -> Void) {
        // Retrieve email and password from keychain
        guard let email = KeychainHelper.shared.read(key: "user_email"),
              let password = KeychainHelper.shared.read(key: "user_password") else {
            completion(false, "No stored credentials found. Please sign in manually first.")
            return
        }
        
        // Use existing sign-in method
        signIn(email: email, password: password, completion: completion)
    }
    
    /// Save credentials to keychain for biometric login
    func saveCredentialsToKeychain(email: String, password: String) {
        KeychainHelper.shared.save(key: "user_email", value: email)
        KeychainHelper.shared.save(key: "user_password", value: password)
    }
    
    /// Remove credentials from keychain
    func removeCredentialsFromKeychain() {
        KeychainHelper.shared.delete(key: "user_email")
        KeychainHelper.shared.delete(key: "user_password")
    }
    
    // MARK: - Private Helpers
    
    // Save user profile to Firestore
    private func saveUserProfile(_ profile: UserProfile, completion: @escaping (Bool, String) -> Void) {
        do {
            try db.collection("users").document(profile.uid).setData(from: profile) { error in
                if let error = error {
                    completion(false, error.localizedDescription)
                } else {
                    completion(true, "Profile saved")
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    // Fetch user profile from Firestore
    private func fetchUserProfile(uid: String) {
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            if let error = error {
                print("Error fetching user profile: \(error)")
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists else {
                print("User profile not found")
                return
            }
            
            do {
                let profile = try snapshot.data(as: UserProfile.self)
                self?.userProfile = profile
                print("✅ User profile loaded: \(profile.name), Business Owner: \(profile.isBusinessOwner)")
            } catch {
                print("Error decoding user profile: \(error)")
            }
        }
    }
    
    // Convert Firebase error codes to readable messages
    private func getReadableError(error: NSError, isSignUp: Bool) -> String {
        guard let errorCode = AuthErrorCode(_bridgedNSError: error) else {
            return error.localizedDescription
        }
        
        switch errorCode.code {
        case .invalidEmail:
            return "❌ Invalid email format. Please check your email address."
        case .emailAlreadyInUse:
            return "❌ This email is already registered. Try logging in instead."
        case .wrongPassword:
            return "❌ Wrong password. Please try again."
        case .weakPassword:
            return "❌ Password is too weak. Use at least 6 characters."
        case .userNotFound:
            return "❌ No account found with this email. Please sign up first."
        case .userDisabled:
            return "❌ This account has been disabled. Contact support."
        case .invalidCredential:
            if isSignUp {
                return "❌ Invalid credentials. Please check your information."
            } else {
                return "❌ Invalid email or password. Please check and try again."
            }
        case .networkError:
            return "❌ Network error. Please check your internet connection."
        case .tooManyRequests:
            return "❌ Too many attempts. Please try again later."
        case .operationNotAllowed:
            return "❌ Email/password sign-in is not enabled. Contact support."
        case .userTokenExpired:
            return "❌ Your session has expired. Please log in again."
        case .invalidUserToken:
            return "❌ Authentication token is invalid. Please log in again."
        case .requiresRecentLogin:
            return "❌ Please log out and log in again to continue."
        default:
            return "❌ Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Keychain Helper

class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}
    
    func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
