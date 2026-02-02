import Foundation
import Combine
import FirebaseFirestore

class AdminStatsManager: ObservableObject {
    private let db = Firestore.firestore()
    
    @Published var stats = AdminStats()
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Cache for statistics (5 minute expiry)
    private var lastFetchTime: Date?
    private let cacheExpiry: TimeInterval = 300 // 5 minutes
    
    /// Fetch all dashboard statistics
    func fetchAllStats() async {
        // Check cache
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheExpiry {
            return // Use cached data
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Fetch all counts in parallel
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
            async let businessTrend = calculateBusinessTrend()
            async let userTrend = calculateUserTrend()
            async let reviewTrend = calculateReviewTrend()
            
            // Wait for all results
            let (bizCount, userCount, reviewCount, claimCount, bookingCount,
                 todayBiz, todayUser, todayRev, marketCount, jobCount,
                 bizTrend, usrTrend, revTrend) = try await (
                businesses, users, reviews, claims, bookings,
                todayBusinesses, todayUsers, todayReviews, marketplace, jobs,
                businessTrend, userTrend, reviewTrend
            )
            
            await MainActor.run {
                stats.totalBusinesses = bizCount
                stats.totalUsers = userCount
                stats.totalReviews = reviewCount
                stats.pendingClaims = claimCount
                stats.activeBookings = bookingCount
                stats.todayNewBusinesses = todayBiz
                stats.todayNewUsers = todayUser
                stats.todayNewReviews = todayRev
                stats.activeMarketplaceListings = marketCount
                stats.activeJobPostings = jobCount
                stats.businessTrend = bizTrend
                stats.userTrend = usrTrend
                stats.reviewTrend = revTrend
                
                isLoading = false
                lastFetchTime = Date()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load statistics: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - Individual Stat Fetchers
    
    private func fetchBusinessCount() async throws -> Int {
        let snapshot = try await db.collection("businesses").getDocuments()
        return snapshot.documents.count
    }
    
    private func fetchUserCount() async throws -> Int {
        let snapshot = try await db.collection("users").getDocuments()
        return snapshot.documents.count
    }
    
    private func fetchReviewCount() async throws -> Int {
        let snapshot = try await db.collection("reviews").getDocuments()
        return snapshot.documents.count
    }
    
    private func fetchPendingClaimCount() async throws -> Int {
        let snapshot = try await db.collection("business_claims")
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        return snapshot.documents.count
    }
    
    private func fetchActiveBookingCount() async throws -> Int {
        let snapshot = try await db.collection("bookings")
            .whereField("status", in: ["pending", "confirmed"])
            .getDocuments()
        return snapshot.documents.count
    }
    
    private func fetchTodayNewBusinesses() async throws -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        let snapshot = try await db.collection("businesses")
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .getDocuments()
        return snapshot.documents.count
    }
    
    private func fetchTodayNewUsers() async throws -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        let snapshot = try await db.collection("users")
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .getDocuments()
        return snapshot.documents.count
    }
    
    private func fetchTodayNewReviews() async throws -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        let snapshot = try await db.collection("reviews")
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .getDocuments()
        return snapshot.documents.count
    }
    
    private func fetchActiveMarketplaceItems() async throws -> Int {
        let snapshot = try await db.collection("marketplace_items")
            .whereField("status", isEqualTo: "active")
            .getDocuments()
        return snapshot.documents.count
    }
    
    private func fetchActiveJobs() async throws -> Int {
        let snapshot = try await db.collection("jobs")
            .whereField("status", isEqualTo: "active")
            .whereField("expiresAt", isGreaterThan: Timestamp(date: Date()))
            .getDocuments()
        return snapshot.documents.count
    }
    
    // MARK: - Trend Calculations
    
    private func calculateBusinessTrend() async throws -> Double {
        // Get count from last 30 days vs previous 30 days
        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!
        let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: now)!
        
        let recentSnapshot = try await db.collection("businesses")
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: thirtyDaysAgo))
            .getDocuments()
        
        let previousSnapshot = try await db.collection("businesses")
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: sixtyDaysAgo))
            .whereField("createdAt", isLessThan: Timestamp(date: thirtyDaysAgo))
            .getDocuments()
        
        let recentCount = Double(recentSnapshot.documents.count)
        let previousCount = Double(previousSnapshot.documents.count)
        
        if previousCount == 0 { return recentCount > 0 ? 100.0 : 0.0 }
        return ((recentCount - previousCount) / previousCount) * 100.0
    }
    
    private func calculateUserTrend() async throws -> Double {
        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!
        let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: now)!
        
        let recentSnapshot = try await db.collection("users")
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: thirtyDaysAgo))
            .getDocuments()
        
        let previousSnapshot = try await db.collection("users")
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: sixtyDaysAgo))
            .whereField("createdAt", isLessThan: Timestamp(date: thirtyDaysAgo))
            .getDocuments()
        
        let recentCount = Double(recentSnapshot.documents.count)
        let previousCount = Double(previousSnapshot.documents.count)
        
        if previousCount == 0 { return recentCount > 0 ? 100.0 : 0.0 }
        return ((recentCount - previousCount) / previousCount) * 100.0
    }
    
    private func calculateReviewTrend() async throws -> Double {
        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!
        let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: now)!
        
        let recentSnapshot = try await db.collection("reviews")
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: thirtyDaysAgo))
            .getDocuments()
        
        let previousSnapshot = try await db.collection("reviews")
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: sixtyDaysAgo))
            .whereField("createdAt", isLessThan: Timestamp(date: thirtyDaysAgo))
            .getDocuments()
        
        let recentCount = Double(recentSnapshot.documents.count)
        let previousCount = Double(previousSnapshot.documents.count)
        
        if previousCount == 0 { return recentCount > 0 ? 100.0 : 0.0 }
        return ((recentCount - previousCount) / previousCount) * 100.0
    }
    
    // MARK: - Chart Data Fetchers
    
    /// Fetch business growth data for the last 12 months
    func fetchBusinessGrowthData() async throws -> [BusinessGrowthData] {
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
                .getDocuments()
            
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            let label = formatter.string(from: startDate)
            
            data.append(BusinessGrowthData(date: startDate, count: snapshot.documents.count, label: label))
        }
        
        return data
    }
    
    /// Fetch category distribution data
    func fetchCategoryDistribution() async throws -> [CategoryDistribution] {
        let snapshot = try await db.collection("businesses").getDocuments()
        
        var categoryCounts: [String: Int] = [:]
        for doc in snapshot.documents {
            if let category = doc.data()["category"] as? String {
                categoryCounts[category, default: 0] += 1
            }
        }
        
        let total = Double(snapshot.documents.count)
        return categoryCounts.map { category, count in
            CategoryDistribution(
                category: category,
                count: count,
                percentage: total > 0 ? (Double(count) / total) * 100.0 : 0.0
            )
        }.sorted { $0.count > $1.count }
    }
    
    /// Fetch geographic distribution data
    func fetchGeographicDistribution() async throws -> [GeographicData] {
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
        
        return cityCounts.map { city, data in
            GeographicData(location: city, count: data.count, businesses: data.ids)
        }.sorted { $0.count > $1.count }
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
    
    /// Clear cache to force refresh
    func clearCache() {
        lastFetchTime = nil
    }
}
