import Foundation
import FirebaseFirestore

/// Represents a verification document uploaded during business claim process
struct ClaimVerificationDocument: Identifiable, Codable, Hashable {
    var id: String
    var documentType: DocumentType
    var fileURL: String
    var fileName: String
    var uploadedAt: Date
    var fileSize: Int64? // in bytes
    
    init(
        id: String = UUID().uuidString,
        documentType: DocumentType,
        fileURL: String,
        fileName: String,
        uploadedAt: Date = Date(),
        fileSize: Int64? = nil
    ) {
        self.id = id
        self.documentType = documentType
        self.fileURL = fileURL
        self.fileName = fileName
        self.uploadedAt = uploadedAt
        self.fileSize = fileSize
    }
    
    /// Types of acceptable verification documents
    enum DocumentType: String, Codable, CaseIterable {
        case businessLicense = "business_license"
        case taxId = "tax_id"
        case utilityBill = "utility_bill"
        case governmentId = "government_id"
        case proofOfOwnership = "proof_of_ownership"
        case other = "other"
        
        var displayName: String {
            switch self {
            case .businessLicense: return "Business License"
            case .taxId: return "Tax ID / EIN"
            case .utilityBill: return "Utility Bill"
            case .governmentId: return "Government ID"
            case .proofOfOwnership: return "Proof of Ownership"
            case .other: return "Other Document"
            }
        }
        
        var description: String {
            switch self {
            case .businessLicense:
                return "Official business registration or license document"
            case .taxId:
                return "Tax identification number or Employer Identification Number (EIN)"
            case .utilityBill:
                return "Recent utility bill showing business address (within last 3 months)"
            case .governmentId:
                return "Valid government-issued photo identification"
            case .proofOfOwnership:
                return "Any document proving business ownership (lease, deed, etc.)"
            case .other:
                return "Any other relevant verification document"
            }
        }
        
        var icon: String {
            switch self {
            case .businessLicense: return "doc.text.fill"
            case .taxId: return "number.circle.fill"
            case .utilityBill: return "bolt.fill"
            case .governmentId: return "person.text.rectangle.fill"
            case .proofOfOwnership: return "building.2.fill"
            case .other: return "doc.fill"
            }
        }
        
        /// Recommended document types for verification
        static var recommended: [DocumentType] {
            [.businessLicense, .taxId, .utilityBill]
        }
    }
    
    // MARK: - Helper Methods
    
    /// Format file size for display
    var formattedFileSize: String {
        guard let size = fileSize else { return "Unknown size" }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    /// Get file extension from URL
    var fileExtension: String {
        return (fileURL as NSString).pathExtension.uppercased()
    }
    
    // MARK: - Validation
    
    /// Validate document meets requirements
    var isValid: Bool {
        return !fileURL.isEmpty && !fileName.isEmpty
    }
    
    // MARK: - Coding Keys for Firestore
    
    enum CodingKeys: String, CodingKey {
        case id
        case documentType
        case fileURL
        case fileName
        case uploadedAt
        case fileSize
    }
    
    // MARK: - Custom Decoding for Firestore Timestamp
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        documentType = try container.decode(DocumentType.self, forKey: .documentType)
        fileURL = try container.decode(String.self, forKey: .fileURL)
        fileName = try container.decode(String.self, forKey: .fileName)
        fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize)
        
        // Handle Firestore Timestamp
        if let timestamp = try? container.decode(Timestamp.self, forKey: .uploadedAt) {
            uploadedAt = timestamp.dateValue()
        } else {
            uploadedAt = try container.decode(Date.self, forKey: .uploadedAt)
        }
    }
}

// MARK: - Extensions

extension ClaimVerificationDocument {
    /// Create a preview/mock document for testing
    static func preview(type: DocumentType = .businessLicense) -> ClaimVerificationDocument {
        ClaimVerificationDocument(
            documentType: type,
            fileURL: "https://example.com/document.pdf",
            fileName: "\(type.displayName).pdf",
            uploadedAt: Date(),
            fileSize: 1024 * 512 // 512 KB
        )
    }
}
