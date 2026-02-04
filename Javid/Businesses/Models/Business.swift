import Foundation
import CoreLocation
import FirebaseFirestore

struct Business: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var category: String
    var description: String
    var phone: String
    var address: String
    var city: String
    var country: String
    var latitude: Double
    var longitude: Double
    var ownerId: String
    var photoURLs: [String] = []
    var rating: Double = 0.0
    var reviewCount: Int = 0
    var workHours: WorkHours?
    var createdAt: Date?
    // ✅ New fields
    var amenities: [String]? = nil
    var socialMedia: SocialMedia? = nil
    var bookingEnabled: Bool = false
    
    var featured: Bool
    var suspended: Bool
    
    // MARK: - Claim System Fields
    var isClaimable: Bool = false              // Only admin-created businesses are claimable
    var claimStatus: String? = nil             // "unclaimed", "pending", "claimed"
    var claimedBy: String? = nil               // User ID of who claimed it
    var claimedAt: Date? = nil                 // When it was claimed
    var claimApprovedBy: String? = nil         // Admin who approved the claim
    
    // MARK: - Audit Trail for Ownership History
    var ownershipHistory: [OwnershipRecord]? = nil
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // Updated initializer with all fields
    init(id: String = UUID().uuidString, name: String, category: String, description: String, phone: String, address: String, city: String, country: String, latitude: Double, longitude: Double, ownerId: String, photoURLs: [String] = [], rating: Double = 0.0, reviewCount: Int = 0, workHours: WorkHours? = nil, amenities: [String]? = nil, socialMedia: SocialMedia? = nil, bookingEnabled: Bool = false, featured: Bool = false, suspended: Bool = false, isClaimable: Bool = false, claimStatus: String? = nil, claimedBy: String? = nil, claimedAt: Date? = nil, claimApprovedBy: String? = nil, ownershipHistory: [OwnershipRecord]? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.phone = phone
        self.address = address
        self.city = city
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.ownerId = ownerId
        self.photoURLs = photoURLs
        self.rating = rating
        self.reviewCount = reviewCount
        self.workHours = workHours
        self.amenities = amenities
        self.socialMedia = socialMedia
        self.bookingEnabled = bookingEnabled
        self.featured = featured
        self.suspended = suspended
        self.isClaimable = isClaimable
        self.claimStatus = claimStatus
        self.claimedBy = claimedBy
        self.claimedAt = claimedAt
        self.claimApprovedBy = claimApprovedBy
        self.ownershipHistory = ownershipHistory
    }
}

struct WorkHours: Codable {
    var monday: DayHours
    var tuesday: DayHours
    var wednesday: DayHours
    var thursday: DayHours
    var friday: DayHours
    var saturday: DayHours
    var sunday: DayHours
    
    init() {
        monday = DayHours()
        tuesday = DayHours()
        wednesday = DayHours()
        thursday = DayHours()
        friday = DayHours()
        saturday = DayHours()
        sunday = DayHours()
    }
}

struct DayHours: Codable {
    var isOpen: Bool
    var openTime: String
    var closeTime: String
    
    init(isOpen: Bool = true, openTime: String = "09:00", closeTime: String = "17:00") {
        self.isOpen = isOpen
        self.openTime = openTime
        self.closeTime = closeTime
    }
}

// ✅ New struct for social media
struct SocialMedia: Codable {
    var website: String?
    var facebook: String?
    var instagram: String?
    var youtube: String?
    
    init(website: String? = nil, facebook: String? = nil, instagram: String? = nil, youtube: String? = nil) {
        self.website = website
        self.facebook = facebook
        self.instagram = instagram
        self.youtube = youtube
    }
}

// MARK: - Ownership History Record

/// Tracks the complete ownership history of a business
struct OwnershipRecord: Codable, Identifiable {
    var id: String
    var ownerId: String
    var ownerName: String
    var ownerEmail: String
    var startDate: Date
    var endDate: Date?
    var transferType: TransferType
    var transferredBy: String?         // Admin ID who approved transfer
    var notes: String?
    
    init(
        id: String = UUID().uuidString,
        ownerId: String,
        ownerName: String,
        ownerEmail: String,
        startDate: Date = Date(),
        endDate: Date? = nil,
        transferType: TransferType,
        transferredBy: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.ownerId = ownerId
        self.ownerName = ownerName
        self.ownerEmail = ownerEmail
        self.startDate = startDate
        self.endDate = endDate
        self.transferType = transferType
        self.transferredBy = transferredBy
        self.notes = notes
    }
    
    enum TransferType: String, Codable {
        case created = "created"           // Original creation
        case claimed = "claimed"           // Claimed by user
        case transferred = "transferred"   // Manually transferred by admin
        
        var displayName: String {
            switch self {
            case .created: return "Created"
            case .claimed: return "Claimed"
            case .transferred: return "Transferred"
            }
        }
    }
    
    // MARK: - Custom Decoding for Firestore Timestamps
    
    enum CodingKeys: String, CodingKey {
        case id, ownerId, ownerName, ownerEmail, startDate, endDate
        case transferType, transferredBy, notes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        ownerId = try container.decode(String.self, forKey: .ownerId)
        ownerName = try container.decode(String.self, forKey: .ownerName)
        ownerEmail = try container.decode(String.self, forKey: .ownerEmail)
        transferType = try container.decode(TransferType.self, forKey: .transferType)
        transferredBy = try container.decodeIfPresent(String.self, forKey: .transferredBy)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        
        // Handle Firestore Timestamps
        if let timestamp = try? container.decode(FirebaseFirestore.Timestamp.self, forKey: .startDate) {
            startDate = timestamp.dateValue()
        } else {
            startDate = try container.decode(Date.self, forKey: .startDate)
        }
        
        if let timestamp = try? container.decode(FirebaseFirestore.Timestamp.self, forKey: .endDate) {
            endDate = timestamp.dateValue()
        } else {
            endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        }
    }
}

// MARK: - Business Extensions for Claim System

extension Business {
    /// Check if business is currently unclaimed
    var isUnclaimed: Bool {
        return isClaimable && (claimStatus == nil || claimStatus == "unclaimed")
    }
    
    /// Check if business has a pending claim
    var hasPendingClaim: Bool {
        return claimStatus == "pending"
    }
    
    /// Check if business is already claimed
    var isClaimed: Bool {
        return claimStatus == "claimed" && claimedBy != nil
    }
    
    /// Get current owner from history
    var currentOwnerRecord: OwnershipRecord? {
        return ownershipHistory?.first { $0.endDate == nil }
    }
    
    /// Get formatted claim status for display
    var claimStatusDisplay: String {
        switch claimStatus {
        case "unclaimed": return "Unclaimed"
        case "pending": return "Claim Pending"
        case "claimed": return "Claimed"
        default: return "Not Claimable"
        }
    }
}

