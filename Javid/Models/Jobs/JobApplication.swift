import Foundation
import FirebaseFirestore

// MARK: - Job Application
struct JobApplication: Identifiable, Codable {
    @DocumentID var id: String?
    var jobId: String
    var jobTitle: String
    var company: String
    var applicantId: String
    var applicantName: String
    var applicantEmail: String
    var applicantPhone: String
    var coverLetter: String
    var resumeURL: String?
    var portfolioURLs: [String] = [] // Changed from portfolioURL to portfolioURLs
    var answers: [String] = [] // Answers to custom questions
    var customAnswers: [String: String] = [:] // Added for question-answer pairs
    var status: ApplicationStatus
    var appliedAt: Date
    var updatedAt: Date
    var viewedByEmployer: Bool = false
    var notes: String? // Employer notes
    
    init(
        jobId: String,
        jobTitle: String,
        company: String,
        applicantId: String,
        applicantName: String,
        applicantEmail: String,
        applicantPhone: String,
        coverLetter: String,
        resumeURL: String? = nil,
        portfolioURLs: [String] = [],
        answers: [String] = [],
        customAnswers: [String: String] = [:]
    ) {
        self.jobId = jobId
        self.jobTitle = jobTitle
        self.company = company
        self.applicantId = applicantId
        self.applicantName = applicantName
        self.applicantEmail = applicantEmail
        self.applicantPhone = applicantPhone
        self.coverLetter = coverLetter
        self.resumeURL = resumeURL
        self.portfolioURLs = portfolioURLs
        self.answers = answers
        self.customAnswers = customAnswers
        self.status = .pending
        self.appliedAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Application Status
enum ApplicationStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case reviewed = "Reviewed"
    case shortlisted = "Shortlisted"
    case interview = "Interview"
    case offered = "Offered"
    case rejected = "Rejected"
    case withdrawn = "Withdrawn"
    
    var color: String {
        switch self {
        case .pending: return "F59E0B"
        case .reviewed: return "3B82F6"
        case .shortlisted: return "8B5CF6"
        case .interview: return "06B6D4"
        case .offered: return "10B981"
        case .rejected: return "EF4444"
        case .withdrawn: return "6B7280"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .reviewed: return "eye.fill"
        case .shortlisted: return "star.fill"
        case .interview: return "person.2.fill"
        case .offered: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .withdrawn: return "arrow.uturn.backward.circle.fill"
        }
    }
}
