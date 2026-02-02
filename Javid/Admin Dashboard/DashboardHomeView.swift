//
//  DashboardHomeView.swift
//  Javid Admin Dashboard
//
//  Main dashboard overview with metrics, charts, and quick actions
//

import SwiftUI
import Charts

struct DashboardHomeView: View {
    @StateObject private var statsManager = AdminStatsManager()
    @EnvironmentObject var adminVM: AdminViewModel
    
    @State private var businessGrowthData: [BusinessGrowthData] = []
    @State private var categoryData: [CategoryDistribution] = []
    @State private var topBusinesses: [TopRatedBusiness] = []
    @State private var geoData: [GeographicData] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Key Metrics
                metricsGrid
                
                // Charts Section
                chartsSection
                
                // Quick Actions
                quickActionsSection
                
                // Recent Activity
                recentActivitySection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Dashboard")
        .task {
            await statsManager.fetchAllStats()
            await loadChartData()
        }
        .refreshable {
            statsManager.clearCache()
            await statsManager.fetchAllStats()
            await loadChartData()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back, \(adminVM.currentUser?.name ?? "Admin")!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Here's what's happening with Javid today")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }
    
    // MARK: - Metrics Grid
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            MetricCard(
                title: "Total Businesses",
                value: "\(statsManager.stats.totalBusinesses)",
                trend: statsManager.stats.businessTrend,
                icon: "building.2.fill",
                color: .blue
            )
            
            MetricCard(
                title: "Total Users",
                value: "\(statsManager.stats.totalUsers)",
                trend: statsManager.stats.userTrend,
                icon: "person.3.fill",
                color: .green
            )
            
            MetricCard(
                title: "Total Reviews",
                value: "\(statsManager.stats.totalReviews)",
                trend: statsManager.stats.reviewTrend,
                icon: "star.fill",
                color: .orange
            )
            
            MetricCard(
                title: "Pending Claims",
                value: "\(statsManager.stats.pendingClaims)",
                trend: nil,
                icon: "doc.text.fill",
                color: .purple
            )
            
            MetricCard(
                title: "Active Bookings",
                value: "\(statsManager.stats.activeBookings)",
                trend: nil,
                icon: "calendar.badge.clock",
                color: .red
            )
            
            MetricCard(
                title: "Today's New Businesses",
                value: "\(statsManager.stats.todayNewBusinesses)",
                trend: nil,
                icon: "sparkles",
                color: .cyan
            )
            
            MetricCard(
                title: "Today's New Users",
                value: "\(statsManager.stats.todayNewUsers)",
                trend: nil,
                icon: "person.badge.plus",
                color: .mint
            )
            
            MetricCard(
                title: "Today's Reviews",
                value: "\(statsManager.stats.todayNewReviews)",
                trend: nil,
                icon: "text.bubble.fill",
                color: .indigo
            )
            
            MetricCard(
                title: "Marketplace Items",
                value: "\(statsManager.stats.activeMarketplaceListings)",
                trend: nil,
                icon: "cart.fill",
                color: .teal
            )
            
            MetricCard(
                title: "Active Jobs",
                value: "\(statsManager.stats.activeJobPostings)",
                trend: nil,
                icon: "briefcase.fill",
                color: .brown
            )
        }
    }
    
    // MARK: - Charts Section
    
    private var chartsSection: some View {
        VStack(spacing: 20) {
            // Business Growth Chart
            if !businessGrowthData.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    AdminSectionHeader(title: "Business Growth", icon: "chart.line.uptrend.xyaxis")
                    
                    Chart(businessGrowthData) { data in
                        LineMark(
                            x: .value("Month", data.label),
                            y: .value("Count", data.count)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Month", data.label),
                            y: .value("Count", data.count)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    .frame(height: 200)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                    )
                }
            }
            
            // Category Distribution Chart
            if !categoryData.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    AdminSectionHeader(title: "Business Categories", icon: "chart.pie.fill")
                    
                    Chart(categoryData.prefix(6)) { data in
                        BarMark(
                            x: .value("Count", data.count),
                            y: .value("Category", data.category)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .annotation(position: .trailing) {
                            Text("\(data.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(height: 250)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                    )
                }
            }
            
            // Top Rated Businesses
            if !topBusinesses.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    AdminSectionHeader(title: "Top Rated Businesses", icon: "star.fill")
                    
                    VStack(spacing: 12) {
                        ForEach(topBusinesses.prefix(5)) { business in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(business.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text(business.category)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    
                                    Text(String(format: "%.1f", business.rating))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text("(\(business.reviewCount))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                    )
                }
            }
            
            // Geographic Distribution
            if !geoData.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    AdminSectionHeader(title: "Businesses by City", icon: "map.fill")
                    
                    VStack(spacing: 12) {
                        ForEach(geoData.prefix(10)) { data in
                            HStack {
                                Text(data.location)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Text("\(data.count) businesses")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                    )
                }
            }
        }
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminSectionHeader(title: "Quick Actions", icon: "bolt.fill")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                AdminQuickActionCard(
                    title: "Add Business",
                    icon: "plus.circle.fill",
                    color: .blue
                ) {
                    // Navigate to add business
                }
                
                AdminQuickActionCard(
                    title: "Review Claims",
                    icon: "checkmark.circle.fill",
                    color: .green,
                    badge: statsManager.stats.pendingClaims
                ) {
                    // Navigate to claims
                }
                
                AdminQuickActionCard(
                    title: "Manage Users",
                    icon: "person.2.fill",
                    color: .purple
                ) {
                    // Navigate to users
                }
                
                AdminQuickActionCard(
                    title: "View Analytics",
                    icon: "chart.bar.fill",
                    color: .orange
                ) {
                    // Navigate to analytics
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Recent Activity Section
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminSectionHeader(
                title: "Recent Activity",
                icon: "clock.fill",
                actionTitle: "View All"
            ) {
                // Navigate to activity log
            }
            
            if adminVM.activityLog.isEmpty {
                EmptyStateView(
                    icon: "clock",
                    title: "No Recent Activity",
                    message: "Admin actions will appear here"
                )
                .frame(height: 200)
            } else {
                VStack(spacing: 12) {
                    ForEach(adminVM.activityLog.prefix(5)) { entry in
                        ActivityLogRow(entry: entry)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Data Loading
    
    private func loadChartData() async {
        do {
            async let growth = statsManager.fetchBusinessGrowthData()
            async let categories = statsManager.fetchCategoryDistribution()
            async let top = statsManager.fetchTopRatedBusinesses()
            async let geo = statsManager.fetchGeographicDistribution()
            
            let (growthData, catData, topData, geoLocData) = try await (growth, categories, top, geo)
            
            businessGrowthData = growthData
            categoryData = catData
            topBusinesses = topData
            geoData = geoLocData
        } catch {
            print("Error loading chart data: \(error)")
        }
    }
}

// MARK: - Quick Action Card

struct AdminQuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    var badge: Int?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(color.opacity(0.15))
                        )
                    
                    if let badge = badge, badge > 0 {
                        Text("\(badge)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Circle().fill(Color.red))
                            .offset(x: 8, y: -8)
                    }
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }
}

// MARK: - Activity Log Row

struct ActivityLogRow: View {
    let entry: ActivityLogEntry
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForAction(entry.action))
                .font(.subheadline)
                .foregroundColor(colorForAction(entry.action))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(colorForAction(entry.action).opacity(0.15))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.action.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("\(entry.adminName) • \(entry.targetName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(timeAgo(from: entry.timestamp))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func iconForAction(_ action: ActivityLogEntry.AdminAction) -> String {
        switch action {
        case .businessCreated, .businessUpdated:
            return "building.2.fill"
        case .businessDeleted:
            return "trash.fill"
        case .userPromoted:
            return "arrow.up.circle.fill"
        case .userDemoted:
            return "arrow.down.circle.fill"
        case .userSuspended:
            return "hand.raised.fill"
        case .userDeleted:
            return "person.fill.xmark"
        case .claimApproved:
            return "checkmark.circle.fill"
        case .claimRejected:
            return "xmark.circle.fill"
        case .reviewDeleted:
            return "star.slash.fill"
        case .bookingCancelled:
            return "calendar.badge.exclamationmark"
        case .itemDeleted, .jobDeleted:
            return "trash.fill"
        case .settingChanged:
            return "gear"
        case .bulkOperation:
            return "square.stack.3d.up.fill"
        case .notificationSent:
            return "bell.fill"
        }
    }
    
    private func colorForAction(_ action: ActivityLogEntry.AdminAction) -> Color {
        switch action {
        case .businessCreated, .userPromoted, .claimApproved:
            return .green
        case .businessDeleted, .userDeleted, .reviewDeleted, .itemDeleted, .jobDeleted:
            return .red
        case .userSuspended, .claimRejected, .bookingCancelled:
            return .orange
        default:
            return .blue
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        
        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }
}
