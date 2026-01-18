import Foundation
import FirebaseFirestore
import CoreLocation

// MARK: - Marketplace Item Model
struct MarketplaceItem: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var price: Double
    var category: MarketplaceCategory
    var condition: ItemCondition
    var location: String // City/area
    var city: String // Add this property
    var latitude: Double
    var longitude: Double
    var sellerId: String
    var sellerName: String
    var sellerEmail: String
    var photoURLs: [String] = []
    var isSold: Bool = false
    var viewCount: Int = 0
    var savedCount: Int = 0
    var createdAt: Date
    var listingStatus: String = "under_review" // "under_review", "active", "sold"
    var statusUpdatedAt: Date = Date()
    
    // Computed property for coordinate
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // Formatted price string
    var formattedPrice: String {
        return String(format: "$%.2f", price)
    }
    
    // Initialize new marketplace item - UPDATED to include all parameters
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        price: Double,
        category: MarketplaceCategory,
        condition: ItemCondition,
        location: String,
        city: String,
        latitude: Double,
        longitude: Double,
        sellerId: String,
        sellerName: String,
        sellerEmail: String,
        photoURLs: [String] = [],
        isSold: Bool = false,
        viewCount: Int = 0,
        savedCount: Int = 0,
        createdAt: Date = Date(),
        listingStatus: String = "under_review",  // NEW
        statusUpdatedAt: Date = Date()           // NEW
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.price = price
        self.category = category
        self.condition = condition
        self.location = location
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
        self.sellerId = sellerId
        self.sellerName = sellerName
        self.sellerEmail = sellerEmail
        self.photoURLs = photoURLs
        self.isSold = isSold
        self.viewCount = viewCount
        self.savedCount = savedCount
        self.createdAt = createdAt
        self.listingStatus = listingStatus      // NEW
        self.statusUpdatedAt = statusUpdatedAt  // NEW
    }
}

// MARK: - Marketplace Category Enum
enum MarketplaceCategory: String, Codable, CaseIterable {
    case electronics = "Electronics"
    case furniture = "Furniture"
    case clothing = "Clothing"
    case vehicles = "Vehicles"
    case books = "Books"
    case sports = "Sports"
    case toys = "Toys"
    case homeAppliances = "Home Appliances"
    case jewelry = "Jewelry"
    case music = "Music"
    case other = "Other"
    
    // Icon for each category
    var icon: String {
        switch self {
        case .electronics: return "laptopcomputer"
        case .furniture: return "sofa"
        case .clothing: return "tshirt"
        case .vehicles: return "car"
        case .books: return "book"
        case .sports: return "sportscourt"
        case .toys: return "teddybear"
        case .homeAppliances: return "washer"
        case .jewelry: return "sparkles"
        case .music: return "music.note"
        case .other: return "square.grid.2x2"
        }
    }
    
    // Color for each category
    var color: String {
        switch self {
        case .electronics: return "3B82F6"
        case .furniture: return "8B5CF6"
        case .clothing: return "EC4899"
        case .vehicles: return "EF4444"
        case .books: return "F59E0B"
        case .sports: return "10B981"
        case .toys: return "F97316"
        case .homeAppliances: return "06B6D4"
        case .jewelry: return "D946EF"
        case .music: return "8B5CF6"
        case .other: return "6B7280"
        }
    }
}

// MARK: - Item Condition Enum
enum ItemCondition: String, Codable, CaseIterable {
    case brandNew = "Brand New"
    case likeNew = "Like New"
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    
    // Description for each condition
    var description: String {
        switch self {
        case .brandNew: return "Never used, in original packaging"
        case .likeNew: return "Lightly used, no visible wear"
        case .excellent: return "Gently used, minimal wear"
        case .good: return "Used with some wear but fully functional"
        case .fair: return "Well used with noticeable wear"
        case .poor: return "Heavy wear, may need repairs"
        }
    }
}
