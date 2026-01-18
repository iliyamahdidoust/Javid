import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class JobApplicationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var applications: [JobApplication] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var applicationsListener: ListenerRegistration?
    
    deinit {
        applicationsListener?.remove()
    }
    
    // MARK: - Fetch User Applications
    func fetchUserApplications() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            return
        }
        
        isLoading = true
        
        // Remove previous listener
        applicationsListener?.remove()
        
        // Add real-time listener
        applicationsListener = db.collection("job_applications")
            .whereField("applicantId", isEqualTo: userId)
            .order(by: "appliedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Failed to load applications: \(error.localizedDescription)"
                    print("❌ Error fetching applications: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No applications found")
                    return
                }
                
                self?.applications = documents.compactMap { doc -> JobApplication? in
                    try? doc.data(as: JobApplication.self)
                }
                
                print("✅ Loaded \(self?.applications.count ?? 0) applications")
            }
    }
    
    // MARK: - Fetch Applications for Job (Employer view)
    func fetchApplicationsForJob(jobId: String, completion: @escaping ([JobApplication]) -> Void) {
        db.collection("job_applications")
            .whereField("jobId", isEqualTo: jobId)
            .order(by: "appliedAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching applications: \(error)")
                    completion([])
                    return
                }
                
                let applications = snapshot?.documents.compactMap { doc -> JobApplication? in
                    try? doc.data(as: JobApplication.self)
                } ?? []
                
                print("✅ Loaded \(applications.count) applications for job")
                completion(applications)
            }
    }
    
    // MARK: - Submit Application
    func submitApplication(_ application: JobApplication, completion: @escaping (Bool, String) -> Void) {
        guard Auth.auth().currentUser != nil else {
            completion(false, "You must be logged in to apply")
            return
        }
        
        // Check if already applied
        db.collection("job_applications")
            .whereField("jobId", isEqualTo: application.jobId)
            .whereField("applicantId", isEqualTo: application.applicantId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion(false, "Error: \(error.localizedDescription)")
                    return
                }
                
                if let existingApplication = snapshot?.documents.first {
                    completion(false, "You have already applied to this job")
                    return
                }
                
                // Submit new application
                do {
                    let docRef = try self?.db.collection("job_applications").addDocument(from: application) { error in
                        if let error = error {
                            completion(false, "Failed to submit application: \(error.localizedDescription)")
                        } else {
                            // Increment application count
                            self?.db.collection("jobs").document(application.jobId).updateData([
                                "applicationCount": FieldValue.increment(Int64(1))
                            ])
                            completion(true, "✅ Application submitted successfully!")
                        }
                    }
                } catch {
                    completion(false, "Failed to encode application: \(error.localizedDescription)")
                }
            }
    }
    
    // MARK: - Update Application Status (Employer)
    func updateApplicationStatus(_ application: JobApplication, status: ApplicationStatus, notes: String? = nil, completion: @escaping (Bool, String) -> Void) {
        guard let applicationId = application.id else {
            completion(false, "Invalid application ID")
            return
        }
        
        var updates: [String: Any] = [
            "status": status.rawValue,
            "updatedAt": Date()
        ]
        
        if let notes = notes {
            updates["notes"] = notes
        }
        
        db.collection("job_applications").document(applicationId).updateData(updates) { error in
            if let error = error {
                completion(false, "Failed to update status: \(error.localizedDescription)")
            } else {
                completion(true, "✅ Status updated to \(status.rawValue)")
            }
        }
    }
    
    // MARK: - Withdraw Application
    func withdrawApplication(_ application: JobApplication, completion: @escaping (Bool, String) -> Void) {
        guard let applicationId = application.id else {
            completion(false, "Invalid application ID")
            return
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false, "You must be logged in")
            return
        }
        
        guard application.applicantId == userId else {
            completion(false, "You can only withdraw your own applications")
            return
        }
        
        db.collection("job_applications").document(applicationId).updateData([
            "status": ApplicationStatus.withdrawn.rawValue,
            "updatedAt": Date()
        ]) { error in
            if let error = error {
                completion(false, "Failed to withdraw application: \(error.localizedDescription)")
            } else {
                // Decrement application count
                self.db.collection("jobs").document(application.jobId).updateData([
                    "applicationCount": FieldValue.increment(Int64(-1))
                ])
                completion(true, "✅ Application withdrawn")
            }
        }
    }
    
    // MARK: - Mark as Viewed (Employer)
    func markAsViewed(_ application: JobApplication) {
        guard let applicationId = application.id else { return }
        
        db.collection("job_applications").document(applicationId).updateData([
            "viewedByEmployer": true
        ])
    }
    
    // MARK: - Check if Applied
    func hasApplied(to jobId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        db.collection("job_applications")
            .whereField("jobId", isEqualTo: jobId)
            .whereField("applicantId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if error != nil {
                    completion(false)
                    return
                }
                
                completion(!(snapshot?.documents.isEmpty ?? true))
            }
    }
    
    // MARK: - Get Application by Job ID
    func getApplication(for jobId: String) -> JobApplication? {
        guard let userId = Auth.auth().currentUser?.uid else { return nil }
        return applications.first { $0.jobId == jobId && $0.applicantId == userId }
    }
    
    // MARK: - Get Applications by Status
    func getApplications(by status: ApplicationStatus) -> [JobApplication] {
        return applications.filter { $0.status == status }
    }
    
    // MARK: - Get Statistics
    func getApplicationStats() -> (total: Int, pending: Int, reviewed: Int, rejected: Int) {
        let total = applications.count
        let pending = applications.filter { $0.status == .pending }.count
        let reviewed = applications.filter { $0.status == .reviewed || $0.status == .shortlisted }.count
        let rejected = applications.filter { $0.status == .rejected }.count
        
        return (total, pending, reviewed, rejected)
    }
}
