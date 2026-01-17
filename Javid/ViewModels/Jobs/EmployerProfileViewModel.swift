import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class EmployerProfileViewModel: ObservableObject {
    @Published var employerProfile: EmployerProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    init() {
        fetchEmployerProfile()
    }
    
    // MARK: - Fetch Employer Profile
    func fetchEmployerProfile() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        db.collection("employer_profiles")
            .document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists else {
                    return
                }
                
                do {
                    self?.employerProfile = try snapshot.data(as: EmployerProfile.self)
                } catch {
                    self?.errorMessage = error.localizedDescription
                }
            }
    }
    
    // MARK: - Create Employer Profile
    func createEmployerProfile(
        companyName: String,
        industry: String,
        companySize: CompanySize,
        description: String,
        website: String,
        location: String,
        contactEmail: String,
        contactPhone: String
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let profile = EmployerProfile(
            userId: userId,
            companyName: companyName,
            industry: industry,
            companySize: companySize,
            description: description,
            website: website,
            location: location,
            contactEmail: contactEmail,
            contactPhone: contactPhone
        )
        
        try db.collection("employer_profiles")
            .document(userId)
            .setData(from: profile)
    }
    
    // MARK: - Update Employer Profile
    func updateEmployerProfile(
        companyName: String,
        industry: String,
        companySize: CompanySize,
        description: String,
        website: String,
        location: String,
        contactEmail: String,
        contactPhone: String
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let updates: [String: Any] = [
            "companyName": companyName,
            "industry": industry,
            "companySize": companySize.rawValue,
            "description": description,
            "website": website,
            "location": location,
            "contactEmail": contactEmail,
            "contactPhone": contactPhone,
            "updatedAt": Timestamp(date: Date())
        ]
        
        try await db.collection("employer_profiles")
            .document(userId)
            .setData(updates, merge: true)
    }
    
    // MARK: - Submit Verification
    func submitVerification(documents: [String], notes: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let updates: [String: Any] = [
            "verificationDocuments": documents,
            "verificationNotes": notes,
            "verificationStatus": VerificationStatus.pending.rawValue,
            "verificationSubmittedAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]
        
        do {
            try await db.collection("employer_profiles")
                .document(userId)
                .setData(updates, merge: true)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to submit verification: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Upload Logo
    func uploadLogo(imageData: Data) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Upload to Cloudinary using the image endpoint
        return try await withCheckedThrowingContinuation { continuation in
            DocumentManager.shared.uploadImage(imageData) { result in
                switch result {
                case .success(let downloadURL):
                    // Update profile with logo URL
                    Task {
                        do {
                            try await self.db.collection("employer_profiles")
                                .document(userId)
                                .setData([
                                    "logoURL": downloadURL,
                                    "updatedAt": Timestamp(date: Date())
                                ], merge: true)
                            continuation.resume(returning: downloadURL)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Delete Profile
    func deleteEmployerProfile() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        try await db.collection("employer_profiles")
            .document(userId)
            .delete()
    }
    
    // MARK: - Check if User is Employer
    func isEmployer() -> Bool {
        return employerProfile != nil
    }
    
    // MARK: - Get Verification Status Message
    func getVerificationStatusMessage() -> String {
        guard let profile = employerProfile else {
            return "Create an employer profile to get started"
        }
        
        switch profile.verificationStatus {
        case .notSubmitted:
            return "Submit verification documents to get verified"
        case .pending:
            return "Your verification is under review. We'll notify you once complete."
        case .approved:
            return "Your employer account is verified! ✓"
        case .rejected:
            if !profile.verificationNotes.isEmpty {
                return "Verification rejected: \(profile.verificationNotes)"
            }
            return "Verification was rejected. Please contact support."
        }
    }
}
