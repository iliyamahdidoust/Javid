import Foundation
import FirebaseFirestore
// swiftlint:disable all

/// Represents a claim request for business ownership
struct BusinessClaim: Identifiable, Codable {
    @DocumentID var id: String?
    
    // MARK: - Business & User Info
    var businessId: String
    var businessName: String              // Cached for display
    var claimantId: String                // User who is claiming
    var claimantName: String              // Cached for display
    var claimantEmail: String             // Cached for display
    
    // MARK: - Claim Details
    var status: BusinessClaimStatus
    var verificationDocuments: [ClaimVerificationDocument]
    var additionalNotes: String?          // Optional message from claimant
    
    // MARK: - Timestamps
    var submittedAt: Date
    var reviewStartedAt: Date?            // When admin started reviewing
    var reviewCompletedAt: Date?          // When admin made final decision
    var lastUpdatedAt: Date
    
    // MARK: - Admin Review
    var reviewedBy: String?               // Admin user ID who reviewed
    var reviewerName: String?             // Admin name (cached)
    var rejectionReason: String?          // If rejected, why?
    var adminNotes: String?               // Internal admin notes
    
    // MARK: - Audit Trail (Complete History)
    var auditTrail: [AuditEntry]
    
    // MARK: - Original Business Owner Info (For Record Keeping)
    var originalOwnerId: String           // Who created/owned business before claim
    var originalOwnerName: String?        // Cached for history
    
    // MARK: - Email Verification
    var emailVerified: Bool               // Whether claimant verified their email
    var verificationCode: String?         // Code sent to business email
    var verificationCodeSentAt: Date?
    var verificationCodeExpiresAt: Date?
    
    // MARK: - Initializer
    
    init(
        id: String? = nil,
        businessId: String,
        businessName: String,
        claimantId: String,
        claimantName: String,
        claimantEmail: String,
        status: BusinessClaimStatus = BusinessClaimStatus.pending,
        verificationDocuments: [ClaimVerificationDocument] = [],
        additionalNotes: String? = nil,
        originalOwnerId: String,
        originalOwnerName: String? = nil,
        emailVerified: Bool = false
    ) {
        self.id = id
        self.businessId = businessId
        self.businessName = businessName
        self.claimantId = claimantId
        self.claimantName = claimantName
        self.claimantEmail = claimantEmail
        self.status = status
        self.verificationDocuments = verificationDocuments
        self.additionalNotes = additionalNotes
        self.submittedAt = Date()
        self.lastUpdatedAt = Date()
        self.originalOwnerId = originalOwnerId
        self.originalOwnerName = originalOwnerName
        self.emailVerified = emailVerified
        
        // Initialize audit trail with submission
        self.auditTrail = [
            AuditEntry(
                action: .submitted,
                performedBy: claimantId,
                performedByName: claimantName,
                notes: "Claim submitted for review"
            )
        ]
    }
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case businessId, businessName
        case claimantId, claimantName, claimantEmail
        case status, verificationDocuments, additionalNotes
        case submittedAt, reviewStartedAt, reviewCompletedAt, lastUpdatedAt
        case reviewedBy, reviewerName, rejectionReason, adminNotes
        case auditTrail
        case originalOwnerId, originalOwnerName
        case emailVerified, verificationCode, verificationCodeSentAt, verificationCodeExpiresAt
    }
    
    // MARK: - Custom Decoding for Firestore Timestamps
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        businessId = try container.decode(String.self, forKey: .businessId)
        businessName = try container.decode(String.self, forKey: .businessName)
        claimantId = try container.decode(String.self, forKey: .claimantId)
        claimantName = try container.decode(String.self, forKey: .claimantName)
        claimantEmail = try container.decode(String.self, forKey: .claimantEmail)
        status = try container.decode(BusinessClaimStatus.self, forKey: .status)
        verificationDocuments = try container.decode([ClaimVerificationDocument].self, forKey: .verificationDocuments)
        additionalNotes = try container.decodeIfPresent(String.self, forKey: .additionalNotes)
        
        // Decode timestamps
        if let timestamp = try? container.decode(Timestamp.self, forKey: .submittedAt) {
            submittedAt = timestamp.dateValue()
        } else {
            submittedAt = try container.decode(Date.self, forKey: .submittedAt)
        }
        
        if let timestamp = try? container.decode(Timestamp.self, forKey: .reviewStartedAt) {
            reviewStartedAt = timestamp.dateValue()
        } else {
            reviewStartedAt = try container.decodeIfPresent(Date.self, forKey: .reviewStartedAt)
        }
        
        if let timestamp = try? container.decode(Timestamp.self, forKey: .reviewCompletedAt) {
            reviewCompletedAt = timestamp.dateValue()
        } else {
            reviewCompletedAt = try container.decodeIfPresent(Date.self, forKey: .reviewCompletedAt)
        }
        
        if let timestamp = try? container.decode(Timestamp.self, forKey: .lastUpdatedAt) {
            lastUpdatedAt = timestamp.dateValue()
        } else {
            lastUpdatedAt = try container.decode(Date.self, forKey: .lastUpdatedAt)
        }
        
        if let timestamp = try? container.decode(Timestamp.self, forKey: .verificationCodeSentAt) {
            verificationCodeSentAt = timestamp.dateValue()
        } else {
            verificationCodeSentAt = try container.decodeIfPresent(Date.self, forKey: .verificationCodeSentAt)
        }
        
        if let timestamp = try? container.decode(Timestamp.self, forKey: .verificationCodeExpiresAt) {
            verificationCodeExpiresAt = timestamp.dateValue()
        } else {
            verificationCodeExpiresAt = try container.decodeIfPresent(Date.self, forKey: .verificationCodeExpiresAt)
        }
        
        reviewedBy = try container.decodeIfPresent(String.self, forKey: .reviewedBy)
        reviewerName = try container.decodeIfPresent(String.self, forKey: .reviewerName)
        rejectionReason = try container.decodeIfPresent(String.self, forKey: .rejectionReason)
        adminNotes = try container.decodeIfPresent(String.self, forKey: .adminNotes)
        auditTrail = try container.decode([AuditEntry].self, forKey: .auditTrail)
        originalOwnerId = try container.decode(String.self, forKey: .originalOwnerId)
        originalOwnerName = try container.decodeIfPresent(String.self, forKey: .originalOwnerName)
        emailVerified = try container.decode(Bool.self, forKey: .emailVerified)
        verificationCode = try container.decodeIfPresent(String.self, forKey: .verificationCode)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(businessId, forKey: .businessId)
        try container.encode(businessName, forKey: .businessName)
        try container.encode(claimantId, forKey: .claimantId)
        try container.encode(claimantName, forKey: .claimantName)
        try container.encode(claimantEmail, forKey: .claimantEmail)
        try container.encode(status, forKey: .status)
        try container.encode(verificationDocuments, forKey: .verificationDocuments)
        try container.encodeIfPresent(additionalNotes, forKey: .additionalNotes)
        try container.encode(submittedAt, forKey: .submittedAt)
        try container.encodeIfPresent(reviewStartedAt, forKey: .reviewStartedAt)
        try container.encodeIfPresent(reviewCompletedAt, forKey: .reviewCompletedAt)
        try container.encode(lastUpdatedAt, forKey: .lastUpdatedAt)
        try container.encodeIfPresent(verificationCodeSentAt, forKey: .verificationCodeSentAt)
        try container.encodeIfPresent(verificationCodeExpiresAt, forKey: .verificationCodeExpiresAt)
        try container.encodeIfPresent(reviewedBy, forKey: .reviewedBy)
        try container.encodeIfPresent(reviewerName, forKey: .reviewerName)
        try container.encodeIfPresent(rejectionReason, forKey: .rejectionReason)
        try container.encodeIfPresent(adminNotes, forKey: .adminNotes)
        try container.encode(auditTrail, forKey: .auditTrail)
        try container.encode(originalOwnerId, forKey: .originalOwnerId)
        try container.encodeIfPresent(originalOwnerName, forKey: .originalOwnerName)
        try container.encode(emailVerified, forKey: .emailVerified)
        try container.encodeIfPresent(verificationCode, forKey: .verificationCode)
    }
}

// MARK: - Audit Entry

/// Represents a single entry in the claim audit trail
struct AuditEntry: Codable, Identifiable {
    var id: String
    var timestamp: Date
    var action: AuditAction
    var performedBy: String           // User ID
    var performedByName: String       // Cached name
    var notes: String?
    
    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        action: AuditAction,
        performedBy: String,
        performedByName: String,
        notes: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.action = action
        self.performedBy = performedBy
        self.performedByName = performedByName
        self.notes = notes
    }
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, action, performedBy, performedByName, notes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        action = try container.decode(AuditAction.self, forKey: .action)
        performedBy = try container.decode(String.self, forKey: .performedBy)
        performedByName = try container.decode(String.self, forKey: .performedByName)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        
        // Handle Firestore Timestamp
        if let firestoreTimestamp = try? container.decode(Timestamp.self, forKey: .timestamp) {
            timestamp = firestoreTimestamp.dateValue()
        } else {
            timestamp = try container.decode(Date.self, forKey: .timestamp)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(action, forKey: .action)
        try container.encode(performedBy, forKey: .performedBy)
        try container.encode(performedByName, forKey: .performedByName)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}

/// Actions that can be recorded in audit trail
enum AuditAction: String, Codable {
    case submitted = "submitted"
    case documentsUploaded = "documents_uploaded"
    case emailVerified = "email_verified"
    case reviewStarted = "review_started"
    case approved = "approved"
    case rejected = "rejected"
    case cancelled = "cancelled"
    case documentAdded = "document_added"
    case documentRemoved = "document_removed"
    case notesUpdated = "notes_updated"
    
    var displayName: String {
        switch self {
        case .submitted: return "Claim Submitted"
        case .documentsUploaded: return "Documents Uploaded"
        case .emailVerified: return "Email Verified"
        case .reviewStarted: return "Review Started"
        case .approved: return "Claim Approved"
        case .rejected: return "Claim Rejected"
        case .cancelled: return "Claim Cancelled"
        case .documentAdded: return "Document Added"
        case .documentRemoved: return "Document Removed"
        case .notesUpdated: return "Notes Updated"
        }
    }
    
    var icon: String {
        switch self {
        case .submitted: return "paperplane.fill"
        case .documentsUploaded: return "doc.badge.plus"
        case .emailVerified: return "envelope.badge.fill"
        case .reviewStarted: return "eye.fill"
        case .approved: return "checkmark.seal.fill"
        case .rejected: return "xmark.seal.fill"
        case .cancelled: return "xmark.circle.fill"
        case .documentAdded: return "plus.circle.fill"
        case .documentRemoved: return "minus.circle.fill"
        case .notesUpdated: return "pencil.circle.fill"
        }
    }
}

// MARK: - Local, unambiguous status for BusinessClaim
enum BusinessClaimStatus: String, Codable {
    case pending
    case underReview
    case approved
    case rejected
    case cancelled
    
    // Helper to match existing usage in BusinessClaim
    var isCancellable: Bool {
        switch self {
        case .pending, .underReview:
            return true
        case .approved, .rejected, .cancelled:
            return false
        }
    }
}

// MARK: - Helper Methods

extension BusinessClaim {
    /// Check if claim can be cancelled by user
    func canBeCancelled(byUserId currentUserId: String) -> Bool {
        return status.isCancellable && claimantId == currentUserId
    }
    
    /// Check if more documents can be added
    var canAddDocuments: Bool {
        return status == BusinessClaimStatus.pending || status == BusinessClaimStatus.underReview
    }
    
    /// Calculate days since submission
    var daysSinceSubmission: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: submittedAt, to: Date()).day ?? 0
        return days
    }
    
    /// Format submission date
    var formattedSubmissionDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: submittedAt)
    }
    
    /// Get latest audit entry
    var latestAuditEntry: AuditEntry? {
        return auditTrail.sorted { $0.timestamp > $1.timestamp }.first
    }
    
    /// Add new audit entry
    mutating func addAuditEntry(_ entry: AuditEntry) {
        auditTrail.append(entry)
        lastUpdatedAt = Date()
    }
}

// MARK: - Preview Helper

extension BusinessClaim {
    static func preview() -> BusinessClaim {
        BusinessClaim(
            businessId: "business123",
            businessName: "Sample Restaurant",
            claimantId: "user123",
            claimantName: "John Doe",
            claimantEmail: "john@example.com",
            status: BusinessClaimStatus.pending,
            verificationDocuments: [
                ClaimVerificationDocument.preview(type: .businessLicense)
            ],
            additionalNotes: "I am the owner of this business",
            originalOwnerId: "admin123",
            originalOwnerName: "Admin User",
            emailVerified: true
        )
    }
}

