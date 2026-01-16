import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine
import UIKit

class JobSeekerProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var profile: JobSeekerProfile?
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
        profileListener = db.collection("job_seeker_profiles")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                    print("❌ Error fetching profile: \(error)")
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    print("No profile found")
                    return
                }
                
                do {
                    var profile = try document.data(as: JobSeekerProfile.self)
                    profile.calculateCompleteness()
                    self?.profile = profile
                    print("✅ Profile loaded: \(profile.fullName)")
                } catch {
                    print("❌ Error decoding profile: \(error)")
                }
            }
    }
    
    // MARK: - Create Profile
    func createProfile(_ profile: JobSeekerProfile, completion: @escaping (Bool, String) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false, "You must be logged in")
            return
        }
        
        var newProfile = profile
        newProfile.userId = userId
        newProfile.calculateCompleteness()
        
        do {
            try db.collection("job_seeker_profiles").addDocument(from: newProfile) { error in
                if let error = error {
                    completion(false, "Failed to create profile: \(error.localizedDescription)")
                } else {
                    completion(true, "✅ Profile created successfully!")
                }
            }
        } catch {
            completion(false, "Failed to encode profile: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Update Profile
    func updateProfile(_ profile: JobSeekerProfile, completion: @escaping (Bool, String) -> Void) {
        guard let profileId = profile.id else {
            completion(false, "Invalid profile ID")
            return
        }
        
        var updatedProfile = profile
        updatedProfile.updatedAt = Date()
        updatedProfile.calculateCompleteness()
        
        do {
            try db.collection("job_seeker_profiles").document(profileId).setData(from: updatedProfile) { error in
                if let error = error {
                    completion(false, "Failed to update profile: \(error.localizedDescription)")
                } else {
                    completion(true, "✅ Profile updated successfully!")
                }
            }
        } catch {
            completion(false, "Failed to encode profile: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Upload Resume
    func uploadResume(_ fileURL: URL, completion: @escaping (String?) -> Void) {
        // TODO: Implement file upload to Firebase Storage or Cloudinary
        // For now, return a placeholder
        completion("resume_url_placeholder")
    }
    
    // MARK: - Upload Profile Photo
    func uploadProfilePhoto(_ image: UIImage, completion: @escaping (String?) -> Void) {
        CloudinaryManager.shared.uploadImage(image) { result in
            switch result {
            case .success(let url):
                print("✅ Profile photo uploaded: \(url)")
                completion(url)
            case .failure(let error):
                print("❌ Upload failed: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
    
    // MARK: - Add Experience
    func addExperience(_ experience: WorkExperience, completion: @escaping (Bool, String) -> Void) {
        guard var profile = profile else {
            completion(false, "Profile not loaded")
            return
        }
        
        profile.experience.append(experience)
        updateProfile(profile, completion: completion)
    }
    
    // MARK: - Update Experience
    func updateExperience(_ experience: WorkExperience, completion: @escaping (Bool, String) -> Void) {
        guard var profile = profile else {
            completion(false, "Profile not loaded")
            return
        }
        
        if let index = profile.experience.firstIndex(where: { $0.id == experience.id }) {
            profile.experience[index] = experience
            updateProfile(profile, completion: completion)
        } else {
            completion(false, "Experience not found")
        }
    }
    
    // MARK: - Delete Experience
    func deleteExperience(_ experience: WorkExperience, completion: @escaping (Bool, String) -> Void) {
        guard var profile = profile else {
            completion(false, "Profile not loaded")
            return
        }
        
        profile.experience.removeAll { $0.id == experience.id }
        updateProfile(profile, completion: completion)
    }
    
    // MARK: - Add Education
    func addEducation(_ education: Education, completion: @escaping (Bool, String) -> Void) {
        guard var profile = profile else {
            completion(false, "Profile not loaded")
            return
        }
        
        profile.education.append(education)
        updateProfile(profile, completion: completion)
    }
    
    // MARK: - Update Education
    func updateEducation(_ education: Education, completion: @escaping (Bool, String) -> Void) {
        guard var profile = profile else {
            completion(false, "Profile not loaded")
            return
        }
        
        if let index = profile.education.firstIndex(where: { $0.id == education.id }) {
            profile.education[index] = education
            updateProfile(profile, completion: completion)
        } else {
            completion(false, "Education not found")
        }
    }
    
    // MARK: - Delete Education
    func deleteEducation(_ education: Education, completion: @escaping (Bool, String) -> Void) {
        guard var profile = profile else {
            completion(false, "Profile not loaded")
            return
        }
        
        profile.education.removeAll { $0.id == education.id }
        updateProfile(profile, completion: completion)
    }
    
    // MARK: - Add Certification
    func addCertification(_ certification: Certification, completion: @escaping (Bool, String) -> Void) {
        guard var profile = profile else {
            completion(false, "Profile not loaded")
            return
        }
        
        profile.certifications.append(certification)
        updateProfile(profile, completion: completion)
    }
    
    // MARK: - Delete Certification
    func deleteCertification(_ certification: Certification, completion: @escaping (Bool, String) -> Void) {
        guard var profile = profile else {
            completion(false, "Profile not loaded")
            return
        }
        
        profile.certifications.removeAll { $0.id == certification.id }
        updateProfile(profile, completion: completion)
    }
    
    // MARK: - Add Skill
    func addSkill(_ skill: String, completion: @escaping (Bool, String) -> Void) {
        guard var profile = profile else {
            completion(false, "Profile not loaded")
            return
        }
        
        if !profile.skills.contains(skill) {
            profile.skills.append(skill)
            updateProfile(profile, completion: completion)
        } else {
            completion(false, "Skill already exists")
        }
    }
    
    // MARK: - Remove Skill
    func removeSkill(_ skill: String, completion: @escaping (Bool, String) -> Void) {
        guard var profile = profile else {
            completion(false, "Profile not loaded")
            return
        }
        
        profile.skills.removeAll { $0 == skill }
        updateProfile(profile, completion: completion)
    }
    
    // MARK: - Check if Profile Exists
    func checkIfProfileExists(completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        db.collection("job_seeker_profiles")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if error != nil {
                    completion(false)
                    return
                }
                
                completion(!(snapshot?.documents.isEmpty ?? true))
            }
    }
}
