import SwiftUI
import FirebaseAuth

struct SellerDashboardView: View {
    @ObservedObject var marketplaceViewModel: MarketplaceViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var selectedSection: DashboardSection = .overview
    @State private var showingAddItem = false
    
    enum DashboardSection: String, CaseIterable {
        case overview = "Overview"
        case listings = "Listings"
        case sold = "Sold"
        case analytics = "Analytics"
        
        var icon: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .listings: return "list.bullet"
            case .sold: return "checkmark.circle.fill"
            case .analytics: return "chart.line.uptrend.xyaxis"
            }
        }
    }
    
    var userItems: [MarketplaceItem] {
        marketplaceViewModel.userItems
    }
    
    var activeListings: [MarketplaceItem] {
        userItems.filter { !$0.isSold }
    }
    
    var soldItems: [MarketplaceItem] {
        userItems.filter { $0.isSold }
    }
    
    var totalViews: Int {
        userItems.reduce(0) { $0 + $1.viewCount }
    }
    
    var totalSaves: Int {
        userItems.reduce(0) { $0 + $1.savedCount }
    }
    
    var totalRevenue: Double {
        soldItems.reduce(0) { $0 + $1.price }
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                sectionTabsSection
                
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedSection {
                        case .overview:
                            overviewContent
                        case .listings:
                            listingsContent
                        case .sold:
                            soldItemsContent
                        case .analytics:
                            analyticsContent
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingAddItem) {
            AddMarketplaceItemView(marketplaceViewModel: marketplaceViewModel)
        }
        .onAppear {
            marketplaceViewModel.fetchUserItems { _ in }
        }
    }
    
    // MARK: - Header
    var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Seller Dashboard")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    if let userName = authViewModel.currentUser?.displayName {
                        Text(userName)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.leading, 12)
                
                Spacer()
                
                Button(action: { showingAddItem = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                        Text("List Item")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(AppRadius.full)
                    .shadow(color: AppColors.primary.opacity(0.3), radius: 6, x: 0, y: 3)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(AppColors.surface)
            
            Divider()
        }
    }
    
    // MARK: - Section Tabs
    var sectionTabsSection: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DashboardSection.allCases, id: \.self) { section in
                        DashboardTabButton(
                            icon: section.icon,
                            title: section.rawValue,
                            isSelected: selectedSection == section
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedSection = section
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(AppColors.surface)
            
            Divider()
        }
    }
    
    // MARK: - Overview Content
    var overviewContent: some View {
        VStack(spacing: 20) {
            // Stats Cards
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    SellerStatCard(
                        icon: "list.bullet",
                        title: "Active Listings",
                        value: "\(activeListings.count)",
                        color: AppColors.primary
                    )
                    
                    SellerStatCard(
                        icon: "checkmark.circle.fill",
                        title: "Sold Items",
                        value: "\(soldItems.count)",
                        color: AppColors.success
                    )
                }
                
                HStack(spacing: 12) {
                    SellerStatCard(
                        icon: "eye.fill",
                        title: "Total Views",
                        value: "\(totalViews)",
                        color: AppColors.info
                    )
                    
                    SellerStatCard(
                        icon: "heart.fill",
                        title: "Total Saves",
                        value: "\(totalSaves)",
                        color: AppColors.error
                    )
                }
                
                SellerStatCard(
                    icon: "dollarsign.circle.fill",
                    title: "Total Revenue",
                    value: String(format: "$%.2f", totalRevenue),
                    color: AppColors.accent,
                    isWide: true
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Recent Listings
            if !userItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Listings")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 1) {
                        ForEach(userItems.prefix(5)) { item in
                            NavigationLink(destination: MarketplaceDetailView(item: item, marketplaceViewModel: marketplaceViewModel)) {
                                SellerListingRow(item: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            
            // Quick Actions
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Actions")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 20)
                
                VStack(spacing: 12) {
                    QuickActionButton(
                        icon: "plus.circle.fill",
                        title: "Create New Listing",
                        subtitle: "List an item for sale",
                        color: AppColors.primary
                    ) {
                        showingAddItem = true
                    }
                    
                    QuickActionButton(
                        icon: "chart.bar.fill",
                        title: "View Analytics",
                        subtitle: "See your performance",
                        color: AppColors.info
                    ) {
                        selectedSection = .analytics
                    }
                    
                    QuickActionButton(
                        icon: "checkmark.circle.fill",
                        title: "Manage Sold Items",
                        subtitle: "View sold listings",
                        color: AppColors.success
                    ) {
                        selectedSection = .sold
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Listings Content
    var listingsContent: some View {
        VStack(spacing: 20) {
            if activeListings.isEmpty {
                emptyListingsView
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(activeListings.count) Active Listing\(activeListings.count == 1 ? "" : "s")")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 2),
                            GridItem(.flexible(), spacing: 2)
                        ],
                        spacing: 2
                    ) {
                        ForEach(activeListings) { item in
                            NavigationLink(destination: MarketplaceDetailView(item: item, marketplaceViewModel: marketplaceViewModel)) {
                                SellerItemCard(item: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Sold Items Content
    var soldItemsContent: some View {
        VStack(spacing: 20) {
            if soldItems.isEmpty {
                emptySoldView
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(soldItems.count) Sold Item\(soldItems.count == 1 ? "" : "s")")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Total Revenue: \(String(format: "$%.2f", totalRevenue))")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.success)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 2),
                            GridItem(.flexible(), spacing: 2)
                        ],
                        spacing: 2
                    ) {
                        ForEach(soldItems) { item in
                            NavigationLink(destination: MarketplaceDetailView(item: item, marketplaceViewModel: marketplaceViewModel)) {
                                SellerItemCard(item: item, isSold: true)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Analytics Content
    var analyticsContent: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Performance Metrics")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 20)
                
                VStack(spacing: 12) {
                    AnalyticsRow(
                        icon: "eye.fill",
                        title: "Avg. Views per Listing",
                        value: userItems.isEmpty ? "0" : String(format: "%.1f", Double(totalViews) / Double(userItems.count)),
                        color: AppColors.info
                    )
                    
                    AnalyticsRow(
                        icon: "heart.fill",
                        title: "Avg. Saves per Listing",
                        value: userItems.isEmpty ? "0" : String(format: "%.1f", Double(totalSaves) / Double(userItems.count)),
                        color: AppColors.error
                    )
                    
                    AnalyticsRow(
                        icon: "percent",
                        title: "Conversion Rate",
                        value: userItems.isEmpty ? "0%" : String(format: "%.1f%%", (Double(soldItems.count) / Double(userItems.count)) * 100),
                        color: AppColors.success
                    )
                    
                    AnalyticsRow(
                        icon: "dollarsign.circle.fill",
                        title: "Avg. Sale Price",
                        value: soldItems.isEmpty ? "$0.00" : String(format: "$%.2f", totalRevenue / Double(soldItems.count)),
                        color: AppColors.accent
                    )
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 20)
            
            // Top Performing
            if !userItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Performing Items")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 1) {
                        ForEach(userItems.sorted(by: { $0.viewCount > $1.viewCount }).prefix(5)) { item in
                            NavigationLink(destination: MarketplaceDetailView(item: item, marketplaceViewModel: marketplaceViewModel)) {
                                TopPerformingItemRow(item: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            
            // Category Breakdown
            if !userItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Category Breakdown")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 8) {
                        ForEach(getCategoryBreakdown(), id: \.category) { breakdown in
                            CategoryBreakdownRow(
                                category: breakdown.category,
                                count: breakdown.count,
                                percentage: breakdown.percentage
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    // MARK: - Empty States
    var emptyListingsView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "tray")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(AppColors.textTertiary)
            
            Text("No active listings")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("Create your first listing to start selling")
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showingAddItem = true }) {
                Text("Create Listing")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(AppColors.primary)
                    .cornerRadius(AppRadius.md)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    var emptySoldView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(AppColors.textTertiary)
            
            Text("No sold items yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("Items you mark as sold will appear here")
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    // MARK: - Helpers
    func getCategoryBreakdown() -> [(category: MarketplaceCategory, count: Int, percentage: Double)] {
        var categoryCount: [MarketplaceCategory: Int] = [:]
        
        for item in userItems {
            categoryCount[item.category, default: 0] += 1
        }
        
        let total = userItems.count
        
        return categoryCount.map { category, count in
            (category: category, count: count, percentage: Double(count) / Double(total) * 100)
        }.sorted { $0.count > $1.count }
    }
}

// MARK: - Supporting Components

struct DashboardTabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? AppColors.primary
                    : (colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.95))
            )
            .cornerRadius(AppRadius.full)
            .shadow(
                color: isSelected ? AppColors.primary.opacity(0.3) : Color.clear,
                radius: isSelected ? 6 : 0,
                x: 0,
                y: isSelected ? 3 : 0
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SellerStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    var isWide: Bool = false
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
        .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.small, radius: 4, x: 0, y: 2)
    }
}

struct SellerListingRow: View {
    let item: MarketplaceItem
    
    var body: some View {
        HStack(spacing: 12) {
            if let firstPhotoURL = item.photoURLs.first,
               let url = URL(string: firstPhotoURL) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipped()
                        .cornerRadius(AppRadius.sm)
                } placeholder: {
                    ZStack {
                        Color.gray.opacity(0.2)
                        ProgressView().scaleEffect(0.7)
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(AppRadius.sm)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                Text(item.formattedPrice)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.primary)
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill").font(.system(size: 10))
                        Text("\(item.viewCount)").font(.system(size: 12))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill").font(.system(size: 10))
                        Text("\(item.savedCount)").font(.system(size: 12))
                    }
                }
                .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            if item.isSold {
                Text("SOLD")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.success)
                    .cornerRadius(AppRadius.sm)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(12)
        .background(AppColors.surface)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(16)
            .background(AppColors.surface)
            .cornerRadius(AppRadius.md)
            .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.small, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SellerItemCard: View {
    let item: MarketplaceItem
    var isSold: Bool = false
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                if let firstPhotoURL = item.photoURLs.first,
                   let url = URL(string: firstPhotoURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                    } placeholder: {
                        ZStack {
                            Color.gray.opacity(0.2)
                            ProgressView().scaleEffect(0.7)
                        }
                        .aspectRatio(1, contentMode: .fill)
                    }
                } else {
                    ZStack {
                        Color.gray.opacity(0.2)
                        Image(systemName: "photo")
                            .font(.system(size: 30))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .aspectRatio(1, contentMode: .fill)
                }
                
                if isSold {
                    ZStack {
                        Color.black.opacity(0.6)
                        VStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                            Text("SOLD")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                    }
                    .aspectRatio(1, contentMode: .fill)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.formattedPrice)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                
                Text(item.title)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill").font(.system(size: 10))
                        Text("\(item.viewCount)").font(.system(size: 11))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill").font(.system(size: 10))
                        Text("\(item.savedCount)").font(.system(size: 11))
                    }
                }
                .foregroundColor(AppColors.textTertiary)
            }
            .padding(10)
            .background(AppColors.surface)
        }
        .background(AppColors.surface)
    }
}

struct AnalyticsRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(14)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
        .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.small, radius: 4, x: 0, y: 2)
    }
}

struct TopPerformingItemRow: View {
    let item: MarketplaceItem
    
    var body: some View {
        HStack(spacing: 12) {
            if let firstPhotoURL = item.photoURLs.first,
               let url = URL(string: firstPhotoURL) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipped()
                        .cornerRadius(AppRadius.sm)
                } placeholder: {
                    ZStack {
                        Color.gray.opacity(0.2)
                        ProgressView().scaleEffect(0.6)
                    }
                    .frame(width: 50, height: 50)
                    .cornerRadius(AppRadius.sm)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill").font(.system(size: 10))
                        Text("\(item.viewCount)").font(.system(size: 11))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill").font(.system(size: 10))
                        Text("\(item.savedCount)").font(.system(size: 11))
                    }
                }
                .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            Text(item.formattedPrice)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppColors.primary)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(12)
        .background(AppColors.surface)
    }
}

struct CategoryBreakdownRow: View {
    let category: MarketplaceCategory
    let count: Int
    let percentage: Double
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: category.icon)
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: category.color))
                    Text(category.rawValue)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Spacer()
                
                Text("\(count) (\(String(format: "%.1f%%", percentage)))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: category.color))
                        .frame(width: geometry.size.width * (percentage / 100), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(12)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
        .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.small, radius: 4, x: 0, y: 2)
    }
}
