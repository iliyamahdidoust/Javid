import Foundation
import FirebaseFirestore

// MARK: - Employer Profile
struct EmployerProfile: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var companyName: String
    var industry: String
    var companySize: CompanySize
    var description: String
    var website: String
    var logoURL: String?
    var location: String
    var contactEmail: String
    var contactPhone: String
    
    // Verification fields
    var isVerified: Bool
    var verificationStatus: VerificationStatus
    var verificationDocuments: [String]
    var verificationSubmittedAt: Date?
    var verificationReviewedAt: Date?
    var verificationNotes: String
    
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: String? = nil,
        userId: String,
        companyName: String,
        industry: String,
        companySize: CompanySize,
        description: String,
        website: String,
        logoURL: String? = nil,
        location: String,
        contactEmail: String,
        contactPhone: String,
        isVerified: Bool = false,
        verificationStatus: VerificationStatus = .notSubmitted,
        verificationDocuments: [String] = [],
        verificationSubmittedAt: Date? = nil,
        verificationReviewedAt: Date? = nil,
        verificationNotes: String = ""
    ) {
        self.id = id
        self.userId = userId
        self.companyName = companyName
        self.industry = industry
        self.companySize = companySize
        self.description = description
        self.website = website
        self.logoURL = logoURL
        self.location = location
        self.contactEmail = contactEmail
        self.contactPhone = contactPhone
        self.isVerified = isVerified
        self.verificationStatus = verificationStatus
        self.verificationDocuments = verificationDocuments
        self.verificationSubmittedAt = verificationSubmittedAt
        self.verificationReviewedAt = verificationReviewedAt
        self.verificationNotes = verificationNotes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Verification Status
enum VerificationStatus: String, Codable, CaseIterable {
    case notSubmitted = "Not Submitted"
    case pending = "Pending Review"
    case approved = "Approved"
    case rejected = "Rejected"
    
    var color: String {
        switch self {
        case .notSubmitted: return "gray"
        case .pending: return "orange"
        case .approved: return "green"
        case .rejected: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .notSubmitted: return "doc.badge.clock"
        case .pending: return "clock.fill"
        case .approved: return "checkmark.seal.fill"
        case .rejected: return "xmark.seal.fill"
        }
    }
}

// MARK: - Company Size
enum CompanySize: String, Codable, CaseIterable {
    case small = "1-10 employees"
    case medium = "11-50 employees"
    case large = "51-200 employees"
    case enterprise = "201-1000 employees"
    case massive = "1000+ employees"
}

// MARK: - Verification Document Type
enum VerificationDocumentType: String, CaseIterable {
    case businessRegistration = "Business Registration"
    case taxID = "Tax ID / EIN"
    case proofOfOwnership = "Proof of Ownership"
    case other = "Other Document"
    
    var icon: String {
        switch self {
        case .businessRegistration: return "building.2.fill"
        case .taxID: return "doc.text.fill"
        case .proofOfOwnership: return "checkmark.shield.fill"
        case .other: return "doc.fill"
        }
    }
    
    var description: String {
        switch self {
        case .businessRegistration:
            return "Certificate of incorporation or business registration"
        case .taxID:
            return "Tax identification number or EIN documentation"
        case .proofOfOwnership:
            return "Document proving business ownership"
        case .other:
            return "Any other supporting documents"
        }
    }
}
