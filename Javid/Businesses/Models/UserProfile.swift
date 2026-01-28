import Foundation
import FirebaseFirestore

struct UserProfile: Identifiable, Codable {
    @DocumentID var id: String?
    var uid: String
    var email: String
    var name: String
    var phoneNumber: String?
    var bio: String?
    var profileImageURL: String?
    var isBusinessOwner: Bool
    var createdAt: Date?
    var updatedAt: Date?
    
    // Computed property for backwards compatibility with displayName
    var displayName: String {
        return name
    }
    
    // MARK: - Initializers
    
    init(
        uid: String,
        email: String,
        name: String,
        phoneNumber: String? = nil,
        bio: String? = nil,
        profileImageURL: String? = nil,
        isBusinessOwner: Bool = false,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.uid = uid
        self.email = email
        self.name = name
        self.phoneNumber = phoneNumber
        self.bio = bio
        self.profileImageURL = profileImageURL
        self.isBusinessOwner = isBusinessOwner
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case uid
        case email
        case name
        case phoneNumber
        case bio
        case profileImageURL
        case isBusinessOwner
        case createdAt
        case updatedAt
    }
    
    // MARK: - Custom Decoding
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        uid = try container.decode(String.self, forKey: .uid)
        email = try container.decode(String.self, forKey: .email)
        name = try container.decode(String.self, forKey: .name)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL)
        isBusinessOwner = try container.decode(Bool.self, forKey: .isBusinessOwner)
        
        // Handle Firestore Timestamps
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        }
        
        if let timestamp = try? container.decode(Timestamp.self, forKey: .updatedAt) {
            updatedAt = timestamp.dateValue()
        } else {
            updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        }
    }
}

// MARK: - Helper Extensions

extension UserProfile {
    /// Get initials for profile placeholder
    var initials: String {
        let components = name.components(separatedBy: " ")
        let firstInitial = components.first?.prefix(1).uppercased() ?? ""
        let lastInitial = components.count > 1 ? components.last?.prefix(1).uppercased() ?? "" : ""
        return firstInitial + lastInitial
    }
    
    /// Get single initial for small placeholders
    var singleInitial: String {
        return String(name.prefix(1).uppercased())
    }
}
