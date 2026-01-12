import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    @Published var userProfile: UserProfile?
    @Published var errorMessage = ""
    
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
            completion(true, "✅ Login successful!")
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.isLoggedIn = false
            self.currentUser = nil
            self.userProfile = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
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
