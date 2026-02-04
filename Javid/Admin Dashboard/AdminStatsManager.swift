//
//  AdminStatsManager.swift
//  Javid Admin Panel
//
//  Improved statistics manager with caching and performance optimization
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class AdminStatsManager: ObservableObject {
    
    // MARK: - Dependencies
    
    private let db = Firestore.firestore()
    
    // MARK: - Published Properties
    
    @Published var stats = AdminStats()
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Cache Properties
    
    private var lastFetchTime: Date?
    private let cacheExpiry: TimeInterval = 300 // 5 minutes
    private var cachedChartData: [String: Any] = [:]
    
    // MARK: - Statistics Fetching
    
    /// Fetch all dashboard statistics with caching
    func fetchAllStats(forceRefresh: Bool = false) async {
        // Check cache
        if !forceRefresh,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheExpiry {
            return // Use cached data
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch all statistics in parallel
            async let businesses = fetchBusinessCount()
            async let users = fetchUserCount()
            async let reviews = fetchReviewCount()
            async let claims = fetchPendingClaimCount()
            async let bookings = fetchActiveBookingCount()
            async let todayBusinesses = fetchTodayNewBusinesses()
            async let todayUsers = fetchTodayNewUsers()
            async let todayReviews = fetchTodayNewReviews()
            async let marketplace = fetchActiveMarketplaceItems()
            async let jobs = fetchActiveJobs()
            
            // Calculate trends
            async let businessTrend = calculateTrend(collection: "businesses")
            async let userTrend = calculateTrend(collection: "users")
            async let reviewTrend = calculateTrend(collection: "reviews")
            async let bookingTrend = calculateTrend(collection: "bookings")
            
            // Additional metrics
            async let avgRating = calculateAverageRating()
            async let suspendedUsers = fetchSuspendedCount(collection: "users")
            async let suspendedBusinesses = fetchSuspendedCount(collection: "businesses")
            
            // Await all results
            let results = try await (
                businesses, users, reviews, claims, bookings,
                todayBusinesses, todayUsers, todayReviews, marketplace, jobs,
                businessTrend, userTrend, reviewTrend, bookingTrend,
                avgRating, suspendedUsers, suspendedBusinesses
            )
            
            // Update stats
            stats.totalBusinesses = results.0
            stats.totalUsers = results.1
            stats.totalReviews = results.2
            stats.pendingClaims = results.3
            stats.activeBookings = results.4
            stats.todayNewBusinesses = results.5
            stats.todayNewUsers = results.6
            stats.todayNewReviews = results.7
            stats.activeMarketplaceListings = results.8
            stats.activeJobPostings = results.9
            stats.businessTrend = results.10
            stats.userTrend = results.11
            stats.reviewTrend = results.12
            stats.bookingTrend = results.13
            stats.averageRating = results.14
            stats.suspendedUsers = results.15
            stats.suspendedBusinesses = results.16
            
            isLoading = false
            lastFetchTime = Date()
            
        } catch {
            errorMessage = "Failed to load statistics: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Individual Stat Fetchers
    
    private func fetchBusinessCount() async throws -> Int {
        let snapshot = try await db.collection("businesses").count.getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }
    
    private func fetchUserCount() async throws -> Int {
        let snapshot = try await db.collection("users").count.getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }
    
    private func fetchReviewCount() async throws -> Int {
        let snapshot = try await db.collection("reviews").count.getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }
    
    private func fetchPendingClaimCount() async throws -> Int {
        let snapshot = try await db.collection("business_claims")
            .whereField("status", isEqualTo: "pending")
            .count
            .getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }
    
    private func fetchActiveBookingCount() async throws -> Int {
        let snapshot = try await db.collection("bookings")
            .whereField("status", in: ["pending", "confirmed"])
            .count
            .getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }
    
    private func fetchTodayNewBusinesses() async throws -> Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let snapshot = try await db.collection("businesses")
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .count
            .getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }
    
    private func fetchTodayNewUsers() async throws -> Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let snapshot = try await db.collection("users")
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .count
            .getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }
    
    private func fetchTodayNewReviews() async throws -> Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let snapshot = try await db.collection("reviews")
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .count
            .getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }
    
    private func fetchActiveMarketplaceItems() async throws -> Int {
        let snapshot = try await db.collection("marketplace_items")
            .whereField("status", isEqualTo: "active")
            .count
            .getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }
    
    private func fetchActiveJobs() async throws -> Int {
        let snapshot = try await db.collection("jobs")
            .whereField("status", isEqualTo: "active")
            .whereField("expiresAt", isGreaterThan: Timestamp(date: Date()))
            .count
            .getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }
    
    private func fetchSuspendedCount(collection: String) async throws -> Int {
        let snapshot = try await db.collection(collection)
            .whereField("isSuspended", isEqualTo: true)
            .count
            .getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }
    
    // MARK: - Trend Calculations
    
    private func calculateTrend(collection: String) async throws -> Double {
        let calendar = Calendar.current
        let now = Date()
        
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now),
              let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: now) else {
            return 0.0
        }
        
        // Recent period (last 30 days)
        let recentSnapshot = try await db.collection(collection)
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: thirtyDaysAgo))
            .count
            .getAggregation(source: .server)
        
        // Previous period (30-60 days ago)
        let previousSnapshot = try await db.collection(collection)
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: sixtyDaysAgo))
            .whereField("createdAt", isLessThan: Timestamp(date: thirtyDaysAgo))
            .count
            .getAggregation(source: .server)
        
        let recentCount = Double(truncating: recentSnapshot.count)
        let previousCount = Double(truncating: previousSnapshot.count)
        
        guard previousCount > 0 else {
            return recentCount > 0 ? 100.0 : 0.0
        }
        
        return ((recentCount - previousCount) / previousCount) * 100.0
    }
    
    private func calculateAverageRating() async throws -> Double {
        let snapshot = try await db.collection("businesses")
            .getDocuments()
        
        let ratings = snapshot.documents.compactMap { doc -> Double? in
            doc.data()["rating"] as? Double
        }
        
        guard !ratings.isEmpty else { return 0.0 }
        return ratings.reduce(0.0, +) / Double(ratings.count)
    }
    
    // MARK: - Chart Data Fetchers
    
    /// Fetch business growth data for the last 12 months
    func fetchBusinessGrowthData() async throws -> [BusinessGrowthData] {
        // Check cache
        if let cached = cachedChartData["businessGrowth"] as? [BusinessGrowthData],
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheExpiry {
            return cached
        }
        
        let calendar = Calendar.current
        let now = Date()
        var data: [BusinessGrowthData] = []
        
        for monthsAgo in (0..<12).reversed() {
            guard let startDate = calendar.date(byAdding: .month, value: -monthsAgo, to: now),
                  let endDate = calendar.date(byAdding: .month, value: -monthsAgo + 1, to: now) else {
                continue
            }
            
            let snapshot = try await db.collection("businesses")
                .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: startDate))
                .whereField("createdAt", isLessThan: Timestamp(date: endDate))
                .count
                .getAggregation(source: .server)
            
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            let label = formatter.string(from: startDate)
            
            data.append(BusinessGrowthData(
                date: startDate,
                count: Int(truncating: snapshot.count),
                label: label
            ))
        }
        
        // Cache the result
        cachedChartData["businessGrowth"] = data
        return data
    }
    
    /// Fetch category distribution data
    func fetchCategoryDistribution() async throws -> [CategoryDistribution] {
        // Check cache
        if let cached = cachedChartData["categoryDistribution"] as? [CategoryDistribution],
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheExpiry {
            return cached
        }
        
        let snapshot = try await db.collection("businesses").getDocuments()
        
        var categoryCounts: [String: Int] = [:]
        for doc in snapshot.documents {
            if let category = doc.data()["category"] as? String {
                categoryCounts[category, default: 0] += 1
            }
        }
        
        let total = Double(snapshot.documents.count)
        let data = categoryCounts.map { category, count in
            CategoryDistribution(
                category: category,
                count: count,
                percentage: total > 0 ? (Double(count) / total) * 100.0 : 0.0
            )
        }.sorted { $0.count > $1.count }
        
        // Cache the result
        cachedChartData["categoryDistribution"] = data
        return data
    }
    
    /// Fetch geographic distribution data
    func fetchGeographicDistribution() async throws -> [GeographicData] {
        // Check cache
        if let cached = cachedChartData["geographicData"] as? [GeographicData],
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheExpiry {
            return cached
        }
        
        let snapshot = try await db.collection("businesses").getDocuments()
        
        var cityCounts: [String: (count: Int, ids: [String])] = [:]
        for doc in snapshot.documents {
            if let city = doc.data()["city"] as? String {
                var current = cityCounts[city] ?? (count: 0, ids: [])
                current.count += 1
                current.ids.append(doc.documentID)
                cityCounts[city] = current
            }
        }
        
        let data = cityCounts.map { city, data in
            GeographicData(location: city, count: data.count, businesses: data.ids)
        }.sorted { $0.count > $1.count }
        
        // Cache the result
        cachedChartData["geographicData"] = data
        return data
    }
    
    /// Fetch top rated businesses
    func fetchTopRatedBusinesses(limit: Int = 10) async throws -> [TopRatedBusiness] {
        let snapshot = try await db.collection("businesses")
            .order(by: "rating", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let name = data["name"] as? String,
                  let rating = data["rating"] as? Double,
                  let category = data["category"] as? String else {
                return nil
            }
            let reviewCount = data["reviewCount"] as? Int ?? 0
            
            return TopRatedBusiness(
                id: doc.documentID,
                name: name,
                rating: rating,
                reviewCount: reviewCount,
                category: category
            )
        }
    }
    
    /// Fetch user activity data for the last 30 days
    func fetchUserActivityData() async throws -> [UserActivityData] {
        let calendar = Calendar.current
        let now = Date()
        var data: [UserActivityData] = []
        
        for daysAgo in (0..<30).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: now),
                  let startOfDay = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: date),
                  let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) else {
                continue
            }
            
            // New users
            let newUsersSnapshot = try await db.collection("users")
                .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                .whereField("createdAt", isLessThanOrEqualTo: Timestamp(date: endOfDay))
                .count
                .getAggregation(source: .server)
            
            // Active users (those who logged in)
            let activeUsersSnapshot = try await db.collection("users")
                .whereField("lastLoginAt", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                .whereField("lastLoginAt", isLessThanOrEqualTo: Timestamp(date: endOfDay))
                .count
                .getAggregation(source: .server)
            
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let label = formatter.string(from: date)
            
            data.append(UserActivityData(
                date: date,
                newUsers: Int(truncating: newUsersSnapshot.count),
                activeUsers: Int(truncating: activeUsersSnapshot.count),
                label: label
            ))
        }
        
        return data
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        lastFetchTime = nil
        cachedChartData.removeAll()
    }
    
    func refreshStats() async {
        clearCache()
        await fetchAllStats(forceRefresh: true)
    }
}
