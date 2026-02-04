//
//  DashboardHomeView.swift
//  Javid Admin Panel
//
//  Redesigned dashboard home with improved UI and performance
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
    @State private var userActivityData: [UserActivityData] = []
    @State private var selectedTimeRange: TimeRange = .month
    
    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        case year = "Year"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                metricsGrid
                quickActionsSection
                chartsSection
                recentActivitySection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadData()
        }
        .refreshable {
            await refreshData()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back,")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(adminVM.currentUser?.name ?? "Admin")
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                Menu {
                    Button(action: { Task { await refreshData() } }) {
                        Label("Refresh Data", systemImage: "arrow.clockwise")
                    }
                    
                    Button(action: { statsManager.clearCache() }) {
                        Label("Clear Cache", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            HStack(spacing: 16) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.green)
                
                Text("All systems operational")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(Date(), style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.1))
            )
        }
    }
    
    // MARK: - Metrics Grid
    
    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminSectionHeader(title: "Overview", icon: "chart.bar.fill")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MetricCard(
                    title: "Total Businesses",
                    value: "\(statsManager.stats.totalBusinesses)",
                    trend: statsManager.stats.businessTrend,
                    icon: "building.2.fill",
                    color: .blue,
                    subtitle: "+\(statsManager.stats.todayNewBusinesses) today"
                )
                
                MetricCard(
                    title: "Total Users",
                    value: "\(statsManager.stats.totalUsers)",
                    trend: statsManager.stats.userTrend,
                    icon: "person.3.fill",
                    color: .green,
                    subtitle: "+\(statsManager.stats.todayNewUsers) today"
                )
                
                MetricCard(
                    title: "Total Reviews",
                    value: "\(statsManager.stats.totalReviews)",
                    trend: statsManager.stats.reviewTrend,
                    icon: "star.fill",
                    color: .orange,
                    subtitle: "+\(statsManager.stats.todayNewReviews) today"
                )
                
                MetricCard(
                    title: "Pending Claims",
                    value: "\(statsManager.stats.pendingClaims)",
                    trend: nil,
                    icon: "doc.text.fill",
                    color: .purple,
                    subtitle: statsManager.stats.pendingClaims > 5 ? "Needs attention" : "Up to date"
                )
                
                MetricCard(
                    title: "Active Bookings",
                    value: "\(statsManager.stats.activeBookings)",
                    trend: statsManager.stats.bookingTrend,
                    icon: "calendar.badge.clock",
                    color: .red
                )
                
                MetricCard(
                    title: "Avg Rating",
                    value: String(format: "%.1f", statsManager.stats.averageRating),
                    trend: nil,
                    icon: "star.circle.fill",
                    color: .yellow
                )
            }
        }
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminSectionHeader(title: "Quick Actions", icon: "bolt.fill")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                AdminQuickActionCard(
                    title: "Review Claims",
                    icon: "checkmark.circle.fill",
                    color: .green,
                    badge: statsManager.stats.pendingClaims
                )
                
                AdminQuickActionCard(
                    title: "Manage Users",
                    icon: "person.2.fill",
                    color: .blue,
                    badge: statsManager.stats.suspendedUsers
                )
                
                AdminQuickActionCard(
                    title: "Businesses",
                    icon: "building.2.fill",
                    color: .purple,
                    badge: statsManager.stats.suspendedBusinesses
                )
                
                AdminQuickActionCard(
                    title: "Analytics",
                    icon: "chart.bar.fill",
                    color: .orange
                )
            }
        }
    }
    
    // MARK: - Charts Section
    
    private var chartsSection: some View {
        VStack(spacing: 24) {
            // Time range selector
            HStack {
                Text("Analytics")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }
            
            // Business Growth Chart
            if !businessGrowthData.isEmpty {
                ChartCard(
                    title: "Business Growth",
                    subtitle: "Last 12 months"
                ) {
                    Chart(businessGrowthData) { data in
                        LineMark(
                            x: .value("Month", data.label),
                            y: .value("Count", data.count)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .interpolationMethod(.catmullRom)
                        .symbol(.circle)
                        
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
                    .chartXAxis {
                        AxisMarks(values: .stride(by: 2))
                    }
                    .frame(height: 200)
                }
            }
            
            // Category Distribution
            if !categoryData.isEmpty {
                ChartCard(
                    title: "Top Categories",
                    subtitle: "By business count"
                ) {
                    Chart(categoryData.prefix(6)) { data in
                        BarMark(
                            x: .value("Count", data.count),
                            y: .value("Category", data.category)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .cornerRadius(6)
                    }
                    .frame(height: 250)
                }
            }
            
            // Top Businesses
            if !topBusinesses.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    AdminSectionHeader(title: "Top Rated Businesses", icon: "star.fill")
                    
                    VStack(spacing: 12) {
                        ForEach(topBusinesses.prefix(5)) { business in
                            TopBusinessRow(business: business)
                        }
                    }
                }
            }
            
            // Geographic Distribution
            if !geoData.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    AdminSectionHeader(title: "Businesses by Location", icon: "map.fill")
                    
                    VStack(spacing: 12) {
                        ForEach(geoData.prefix(8)) { data in
                            GeographicRow(data: data)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Recent Activity
    
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
                    ForEach(adminVM.activityLog.prefix(10)) { entry in
                        ActivityLogRow(entry: entry)
                    }
                }
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        await statsManager.fetchAllStats()
        await loadChartData()
    }
    
    private func refreshData() async {
        await statsManager.refreshStats()
        await loadChartData()
    }
    
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
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(color.opacity(0.15))
                        )
                    
                    if let badge = badge, badge > 0 {
                        Text("\(badge)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                            .offset(x: 8, y: -8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let badge = badge, badge > 0 {
                        Text("\(badge) pending")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chart Card

struct ChartCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: () -> Content
    
    init(title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }
}

// MARK: - Top Business Row

struct TopBusinessRow: View {
    let business: TopRatedBusiness
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "building.2.fill")
                        .foregroundColor(.orange)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(business.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
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

// MARK: - Geographic Row

struct GeographicRow: View {
    let data: GeographicData
    
    var body: some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(.blue)
            
            Text(data.location)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text("\(data.count)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
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
                .frame(width: 36, height: 36)
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
                    .lineLimit(1)
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
        case .businessFeatured:
            return "star.fill"
        case .businessSuspended:
            return "hand.raised.fill"
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
        case .dataExported:
            return "square.and.arrow.up"
        }
    }
    
    private func colorForAction(_ action: ActivityLogEntry.AdminAction) -> Color {
        switch action {
        case .businessCreated, .userPromoted, .claimApproved, .businessFeatured:
            return .green
        case .businessDeleted, .userDeleted, .reviewDeleted, .itemDeleted, .jobDeleted:
            return .red
        case .userSuspended, .claimRejected, .bookingCancelled, .businessSuspended:
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
            return "\(seconds / 60)m ago"
        } else if seconds < 86400 {
            return "\(seconds / 3600)h ago"
        } else {
            return "\(seconds / 86400)d ago"
        }
    }
}
