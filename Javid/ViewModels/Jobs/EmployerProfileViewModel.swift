import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine
import UIKit

class EmployerProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var profile: EmployerProfile?
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var profileListener: ListenerRegistration?
    
    deinit {
        profileListener?.remove()
    }
    
    // MARK: - Fetch Profile
    func fetchProfile() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            return
        }
        
        isLoading = true
        
        // Remove previous listener
        profileListener?.remove()
        
        // Add real-time listener
        profileListener = db.collection("employer_profiles")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                    print("❌ Error fetching profile: \(error)")
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    print("No employer profile found")
                    return
                }
                
                do {
                    let profile = try document.data(as: EmployerProfile.self)
                    self?.profile = profile
                    print("✅ Employer profile loaded: \(profile.companyName)")
                } catch {
                    print("❌ Error decoding profile: \(error)")
                }
            }
    }
    
    // MARK: - Create Profile
    func createProfile(_ profile: EmployerProfile, completion: @escaping (Bool, String) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false, "You must be logged in")
            return
        }
        
        var newProfile = profile
        newProfile.userId = userId
        
        do {
            try db.collection("employer_profiles").addDocument(from: newProfile) { error in
                if let error = error {
                    completion(false, "Failed to create profile: \(error.localizedDescription)")
                } else {
                    completion(true, "✅ Company profile created successfully!")
                }
            }
        } catch {
            completion(false, "Failed to encode profile: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Update Profile
    func updateProfile(_ profile: EmployerProfile, completion: @escaping (Bool, String) -> Void) {
        guard let profileId = profile.id else {
            completion(false, "Invalid profile ID")
            return
        }
        
        var updatedProfile = profile
        updatedProfile.updatedAt = Date()
        
        do {
            try db.collection("employer_profiles").document(profileId).setData(from: updatedProfile) { error in
                if let error = error {
                    completion(false, "Failed to update profile: \(error.localizedDescription)")
                } else {
                    completion(true, "✅ Company profile updated successfully!")
                }
            }
        } catch {
            completion(false, "Failed to encode profile: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Submit for Verification
    func submitForVerification(documents: [UIImage], completion: @escaping (Bool, String) -> Void) {
        guard var profile = profile else {
            completion(false, "Profile not loaded")
            return
        }
        
        guard profile.verificationStatus != .pending && profile.verificationStatus != .verified else {
            completion(false, "Verification already submitted or approved")
            return
        }
        
        // Upload documents
        let group = DispatchGroup()
        var uploadedURLs: [String] = []
        
        for document in documents {
            group.enter()
            CloudinaryManager.shared.uploadImage(document) { result in
                switch result {
                case .success(let url):
                    uploadedURLs.append(url)
                case .failure(let error):
                    print("❌ Document upload failed: \(error)")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard !uploadedURLs.isEmpty else {
                completion(false, "Failed to upload documents")
                return
            }
            
            profile.verificationDocuments = uploadedURLs
            profile.verificationStatus = .pending
            profile.verificationSubmittedAt = Date()
            
            self?.updateProfile(profile) { success, message in
                if success {
                    completion(true, "✅ Verification submitted! We'll review within 2-3 business days.")
                } else {
                    completion(false, message)
                }
            }
        }
    }
    
    // MARK: - Upload Company Logo
    func uploadCompanyLogo(_ image: UIImage, completion: @escaping (String?) -> Void) {
        CloudinaryManager.shared.uploadImage(image) { result in
            switch result {
            case .success(let url):
                print("✅ Company logo uploaded: \(url)")
                completion(url)
            case .failure(let error):
                print("❌ Upload failed: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
    
    // MARK: - Upload Cover Photo
    func uploadCoverPhoto(_ image: UIImage, completion: @escaping (String?) -> Void) {
        CloudinaryManager.shared.uploadImage(image) { result in
            switch result {
            case .success(let url):
                print("✅ Cover photo uploaded: \(url)")
                completion(url)
            case .failure(let error):
                print("❌ Upload failed: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
    
    // MARK: - Add Location
    func addLocation(_ location: CompanyLocation, completion: @escaping (Bool, String) -> Void) {
        guard var profile = profile else {
            completion(false, "Profile not loaded")
            return
        }
        
        profile.locations.append(location)
        updateProfile(profile, completion: completion)
    }
    
    // MARK: - Remove Location
    func removeLocation(_ location: CompanyLocation, completion: @escaping (Bool, String) -> Void) {
        guard var profile = profile else {
            completion(false, "Profile not loaded")
            return
        }
        
        profile.locations.removeAll { $0.id == location.id }
        updateProfile(profile, completion: completion)
    }
    
    // MARK: - Add Benefit
    func addBenefit(_ benefit: String, completion: @escaping (Bool, String) -> Void) {
        guard var profile = profile else {
            completion(false, "Profile not loaded")
            return
        }
        
        if !profile.benefits.contains(benefit) {
            profile.benefits.append(benefit)
            updateProfile(profile, completion: completion)
        } else {
            completion(false, "Benefit already exists")
        }
    }
    
    // MARK: - Remove Benefit
    func removeBenefit(_ benefit: String, completion: @escaping (Bool, String) -> Void) {
        guard var profile = profile else {
            completion(false, "Profile not loaded")
            return
        }
        
        profile.benefits.removeAll { $0 == benefit }
        updateProfile(profile, completion: completion)
    }
    
    // MARK: - Check if Profile Exists
    func checkIfProfileExists(completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        db.collection("employer_profiles")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if error != nil {
                    completion(false)
                    return
                }
                
                completion(!(snapshot?.documents.isEmpty ?? true))
            }
    }
    
    // MARK: - Increment Active Jobs Count
    func incrementActiveJobsCount() {
        guard let profileId = profile?.id else { return }
        
        db.collection("employer_profiles").document(profileId).updateData([
            "activeJobsCount": FieldValue.increment(Int64(1))
        ])
    }
    
    // MARK: - Decrement Active Jobs Count
    func decrementActiveJobsCount() {
        guard let profileId = profile?.id else { return }
        
        db.collection("employer_profiles").document(profileId).updateData([
            "activeJobsCount": FieldValue.increment(Int64(-1))
        ])
    }
    
    // MARK: - Increment Total Hires
    func incrementTotalHires() {
        guard let profileId = profile?.id else { return }
        
        db.collection("employer_profiles").document(profileId).updateData([
            "totalHires": FieldValue.increment(Int64(1))
        ])
    }
}
