import Foundation
import FirebaseFirestore

// MARK: - Job Save Model
struct JobSave: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var jobId: String
    var createdAt: Date
    
    init(userId: String, jobId: String) {
        self.userId = userId
        self.jobId = jobId
        self.createdAt = Date()
    }
}
