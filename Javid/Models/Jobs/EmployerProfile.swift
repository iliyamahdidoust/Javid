import Foundation
import FirebaseFirestore

// MARK: - Employer Profile
struct EmployerProfile: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var companyName: String
    var companyEmail: String
    var companyPhone: String
    var companyLogo: String?
    var companyCoverPhoto: String?
    var industry: String
    var companySize: CompanySize
    var foundedYear: Int?
    var website: String?
    var linkedInURL: String?
    var description: String
    var mission: String?
    var culture: String?
    var benefits: [String]
    var locations: [CompanyLocation]
    var verificationStatus: VerificationStatus
    var verificationDocuments: [String] // URLs to verification documents
    var verificationSubmittedAt: Date?
    var verifiedAt: Date?
    var rejectionReason: String?
    var createdAt: Date
    var updatedAt: Date
    var isActive: Bool = true
    var activeJobsCount: Int = 0
    var totalHires: Int = 0
    
    init(
        userId: String,
        companyName: String,
        companyEmail: String,
        companyPhone: String = "",
        industry: String = "",
        companySize: CompanySize = .small,
        description: String = ""
    ) {
        self.userId = userId
        self.companyName = companyName
        self.companyEmail = companyEmail
        self.companyPhone = companyPhone
        self.industry = industry
        self.companySize = companySize
        self.description = description
        self.benefits = []
        self.locations = []
        self.verificationStatus = .unverified
        self.verificationDocuments = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Company Size
enum CompanySize: String, Codable, CaseIterable {
    case startup = "1-10 employees"
    case small = "11-50 employees"
    case medium = "51-200 employees"
    case large = "201-1000 employees"
    case enterprise = "1000+ employees"
}

// MARK: - Company Location
struct CompanyLocation: Codable, Identifiable {
    var id = UUID().uuidString
    var name: String // e.g., "Headquarters", "Branch Office"
    var address: String
    var city: String
    var country: String
    var latitude: Double
    var longitude: Double
    var isHeadquarters: Bool
}

// MARK: - Verification Status
enum VerificationStatus: String, Codable {
    case unverified = "Unverified"
    case pending = "Pending Review"
    case verified = "Verified"
    case rejected = "Rejected"
    
    var color: String {
        switch self {
        case .unverified: return "6B7280"
        case .pending: return "F59E0B"
        case .verified: return "10B981"
        case .rejected: return "EF4444"
        }
    }
    
    var icon: String {
        switch self {
        case .unverified: return "questionmark.circle"
        case .pending: return "clock.fill"
        case .verified: return "checkmark.seal.fill"
        case .rejected: return "xmark.circle.fill"
        }
    }
}
