import Foundation

// MARK: - Dashboard Statistics

struct AdminStats: Codable {
    var totalBusinesses: Int
    var totalUsers: Int
    var totalReviews: Int
    var pendingClaims: Int
    var activeBookings: Int
    var todayNewBusinesses: Int
    var todayNewUsers: Int
    var todayNewReviews: Int
    var activeMarketplaceListings: Int
    var activeJobPostings: Int
    
    // Trends (percentage change from previous period)
    var businessTrend: Double
    var userTrend: Double
    var reviewTrend: Double
    var bookingTrend: Double
    
    // Additional metrics
    var averageRating: Double
    var totalViews: Int
    var totalFavorites: Int
    var suspendedUsers: Int
    var suspendedBusinesses: Int
    
    init() {
        self.totalBusinesses = 0
        self.totalUsers = 0
        self.totalReviews = 0
        self.pendingClaims = 0
        self.activeBookings = 0
        self.todayNewBusinesses = 0
        self.todayNewUsers = 0
        self.todayNewReviews = 0
        self.activeMarketplaceListings = 0
        self.activeJobPostings = 0
        self.businessTrend = 0.0
        self.userTrend = 0.0
        self.reviewTrend = 0.0
        self.bookingTrend = 0.0
        self.averageRating = 0.0
        self.totalViews = 0
        self.totalFavorites = 0
        self.suspendedUsers = 0
        self.suspendedBusinesses = 0
    }
}

// MARK: - Chart Data Models

struct BusinessGrowthData: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
    let label: String
}

struct CategoryDistribution: Identifiable {
    let id = UUID()
    let category: String
    let count: Int
    let percentage: Double
}

struct GeographicData: Identifiable {
    let id = UUID()
    let location: String
    let count: Int
    let businesses: [String]
}

struct TopRatedBusiness: Identifiable {
    let id: String
    let name: String
    let rating: Double
    let reviewCount: Int
    let category: String
}

struct UserActivityData: Identifiable {
    let id = UUID()
    let date: Date
    let newUsers: Int
    let activeUsers: Int
    let label: String
}

struct RevenueData: Identifiable {
    let id = UUID()
    let date: Date
    let bookings: Int
    let revenue: Double
    let label: String
}

// MARK: - Activity Log

struct ActivityLogEntry: Identifiable, Codable {
    let id: String
    let adminId: String
    let adminName: String
    let action: AdminAction
    let targetType: String
    let targetId: String
    let targetName: String
    let details: String
    let timestamp: Date
    
    enum AdminAction: String, Codable {
        case businessCreated = "Business Created"
        case businessUpdated = "Business Updated"
        case businessDeleted = "Business Deleted"
        case businessFeatured = "Business Featured"
        case businessSuspended = "Business Suspended"
        case userPromoted = "User Promoted"
        case userDemoted = "User Demoted"
        case userSuspended = "User Suspended"
        case userDeleted = "User Deleted"
        case claimApproved = "Claim Approved"
        case claimRejected = "Claim Rejected"
        case reviewDeleted = "Review Deleted"
        case bookingCancelled = "Booking Cancelled"
        case itemDeleted = "Marketplace Item Deleted"
        case jobDeleted = "Job Deleted"
        case settingChanged = "Setting Changed"
        case bulkOperation = "Bulk Operation"
        case notificationSent = "Notification Sent"
        case dataExported = "Data Exported"
    }
}

// MARK: - Filter Criteria

struct AdminFilter: Equatable {
    var searchText: String = ""
    var category: String?
    var city: String?
    var country: String?
    var status: String?
    var dateRange: DateRange?
    var rating: Int?
    var claimStatus: String?
    var role: String?
    
    struct DateRange: Equatable {
        let start: Date
        let end: Date
    }
    
    var isActive: Bool {
        return !searchText.isEmpty ||
               category != nil ||
               city != nil ||
               country != nil ||
               status != nil ||
               dateRange != nil ||
               rating != nil ||
               claimStatus != nil ||
               role != nil
    }
    
    mutating func reset() {
        searchText = ""
        category = nil
        city = nil
        country = nil
        status = nil
        dateRange = nil
        rating = nil
        claimStatus = nil
        role = nil
    }
}

// MARK: - Export Options

enum ExportFormat: String, CaseIterable {
    case csv = "CSV"
    case excel = "Excel"
    case pdf = "PDF"
    case json = "JSON"
    
    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .excel: return "xlsx"
        case .pdf: return "pdf"
        case .json: return "json"
        }
    }
    
    var icon: String {
        switch self {
        case .csv: return "tablecells"
        case .excel: return "tablecells.fill"
        case .pdf: return "doc.fill"
        case .json: return "doc.text.fill"
        }
    }
}

// MARK: - Notification Management

struct NotificationTemplate: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var targetAudience: TargetAudience
    var scheduledDate: Date?
    
    enum TargetAudience: String, CaseIterable {
        case allUsers = "All Users"
        case businessOwners = "Business Owners"
        case regularUsers = "Regular Users"
        case specificCity = "Specific City"
        case specificUser = "Specific User"
        case admins = "Admins"
    }
}

// MARK: - System Settings

struct AdminSettings: Codable {
    var enableAutoApproval: Bool
    var requireDocumentVerification: Bool
    var maxClaimsPending: Int
    var autoSuspendThreshold: Int
    var enableEmailNotifications: Bool
    var enablePushNotifications: Bool
    var maintenanceMode: Bool
    var featureFlags: [String: Bool]
    
    init() {
        self.enableAutoApproval = false
        self.requireDocumentVerification = true
        self.maxClaimsPending = 10
        self.autoSuspendThreshold = 5
        self.enableEmailNotifications = true
        self.enablePushNotifications = true
        self.maintenanceMode = false
        self.featureFlags = [:]
    }
}

// MARK: - Performance Metrics

struct PerformanceMetrics {
    var avgResponseTime: Double
    var activeConnections: Int
    var cacheHitRate: Double
    var errorRate: Double
    var uptime: Double
    
    init() {
        self.avgResponseTime = 0.0
        self.activeConnections = 0
        self.cacheHitRate = 0.0
        self.errorRate = 0.0
        self.uptime = 100.0
    }
}
