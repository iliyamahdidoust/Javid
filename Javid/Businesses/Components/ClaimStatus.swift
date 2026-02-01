import Foundation

/// Represents the lifecycle status of a business claim
enum ClaimStatus: String, Codable, CaseIterable {
    case pending = "pending"           // Claim submitted, awaiting admin review
    case underReview = "under_review"  // Admin is actively reviewing
    case approved = "approved"         // Claim approved, ownership transferred
    case rejected = "rejected"         // Claim rejected by admin
    case cancelled = "cancelled"       // Cancelled by user before review
    
    var displayName: String {
        switch self {
        case .pending: return "Pending Review"
        case .underReview: return "Under Review"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "orange"
        case .underReview: return "blue"
        case .approved: return "green"
        case .rejected: return "red"
        case .cancelled: return "gray"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .underReview: return "magnifyingglass.circle.fill"
        case .approved: return "checkmark.seal.fill"
        case .rejected: return "xmark.circle.fill"
        case .cancelled: return "minus.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .pending:
            return "Your claim has been submitted and is waiting for admin review."
        case .underReview:
            return "An administrator is currently reviewing your claim and verification documents."
        case .approved:
            return "Congratulations! Your claim has been approved and you are now the owner of this business."
        case .rejected:
            return "Your claim has been rejected. Please check the rejection reason and submit a new claim if needed."
        case .cancelled:
            return "This claim was cancelled before review completion."
        }
    }
    
    /// Whether this status allows the user to cancel the claim
    var isCancellable: Bool {
        return self == .pending || self == .underReview
    }
    
    /// Whether this is a final status (no further changes expected)
    var isFinal: Bool {
        return self == .approved || self == .rejected || self == .cancelled
    }
}
