//
//  AdminStats.swift
//  Javid Admin Dashboard
//
//  Dashboard statistics and metrics models
//

import Foundation

/// Statistics for the dashboard home view
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
    }
}

/// Business growth data point for charts
struct BusinessGrowthData: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
    let label: String
}

/// Category distribution for pie charts
struct CategoryDistribution: Identifiable {
    let id = UUID()
    let category: String
    let count: Int
    let percentage: Double
}

/// Geographic distribution data
struct GeographicData: Identifiable {
    let id = UUID()
    let location: String // City or Country
    let count: Int
    let businesses: [String] // Business IDs in this location
}

/// Top rated businesses data
struct TopRatedBusiness: Identifiable {
    let id: String
    let name: String
    let rating: Double
    let reviewCount: Int
    let category: String
}

/// Activity log entry for audit trail
struct ActivityLogEntry: Identifiable, Codable {
    let id: String
    let adminId: String
    let adminName: String
    let action: AdminAction
    let targetType: String // "business", "user", "claim", "review", etc.
    let targetId: String
    let targetName: String
    let details: String
    let timestamp: Date
    
    enum AdminAction: String, Codable {
        case businessCreated = "Business Created"
        case businessUpdated = "Business Updated"
        case businessDeleted = "Business Deleted"
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
    }
}

/// Export format options
enum ExportFormat: String, CaseIterable {
    case csv = "CSV"
    case excel = "Excel"
    case pdf = "PDF"
    
    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .excel: return "xlsx"
        case .pdf: return "pdf"
        }
    }
}

/// Filter criteria for various admin views
struct AdminFilter {
    var searchText: String = ""
    var category: String?
    var city: String?
    var country: String?
    var status: String?
    var dateRange: DateRange?
    var rating: Int?
    var claimStatus: String?
    var role: String?
    
    struct DateRange {
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

/// Notification template for sending to users
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
    }
}
