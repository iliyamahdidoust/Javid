import SwiftUI
import CoreLocation
import FirebaseAuth

struct MarketplaceView: View {
    @StateObject private var marketplaceViewModel = MarketplaceViewModel()
    @StateObject private var locationManager = LocationManager()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var selectedCategory: MarketplaceCategory? = nil
    @State private var showingAddItem = false
    @State private var showingFilters = false
    @State private var isRefreshing = false
    @State private var showingLocationPermission = false
    @State private var selectedTab = 0 // 0: Browse, 1: My Listings, 2: Saved
    
    @Environment(\.colorScheme) var colorScheme
    
    var filteredItems: [MarketplaceItem] {
        var items = marketplaceViewModel.items
        
        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }
        
        // Don't show sold items in main feed (optional)
        // items = items.filter { !$0.isSold }
        
        return items
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Section
                    VStack(spacing: AppSpacing.md) {
                        // Title
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Marketplace")
                                    .font(AppFonts.largeTitle)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("Buy and sell locally")
                                    .font(AppFonts.callout)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            // Search Button
                            NavigationLink(destination: MarketplaceSearchView(marketplaceViewModel: marketplaceViewModel)) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(AppColors.primary)
                                    .frame(width: 44, height: 44)
                                    .background(AppColors.surface)
                                    .cornerRadius(AppRadius.full)
                                    .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.small, radius: 4, x: 0, y: 2)
                            }
                            
                            // Add Item Button (only for logged in users)
                            if authViewModel.isLoggedIn {
                                Button(action: {
                                    showingAddItem = true
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(AppColors.primary)
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.sm)
                        
                        // Tab Selector
                        tabSelector
                        
                        // Categories (only show in Browse tab)
                        if selectedTab == 0 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    // All category
                                    MarketplaceCategoryChip(
                                        category: nil,
                                        isSelected: selectedCategory == nil
                                    ) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedCategory = nil
                                        }
                                    }
                                    
                                    ForEach(MarketplaceCategory.allCases, id: \.self) { category in
                                        MarketplaceCategoryChip(
                                            category: category,
                                            isSelected: selectedCategory == category
                                        ) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                selectedCategory = category
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, AppSpacing.md)
                            }
                        }
                    }
                    .padding(.bottom, AppSpacing.md)
                    .background(AppColors.surface)
                    
                    // Content based on selected tab
                    if selectedTab == 0 {
                        browseContent
                    } else if selectedTab == 1 {
                        myListingsContent
                    } else {
                        savedItemsContent
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddItem) {
                AddMarketplaceItemView(marketplaceViewModel: marketplaceViewModel)
            }
            .onAppear {
                requestLocationIfNeeded()
            }
        }
    }
    
    // MARK: - Tab Selector
    
    var tabSelector: some View {
        HStack(spacing: 0) {
            // Browse Tab
            TabButton(
                icon: "square.grid.2x2",
                title: "Browse",
                isSelected: selectedTab == 0
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = 0
                }
            }
            
            // My Listings Tab
            if authViewModel.isLoggedIn {
                TabButton(
                    icon: "list.bullet",
                    title: "My Listings",
                    isSelected: selectedTab == 1,
                    count: marketplaceViewModel.getUserItems().count
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = 1
                    }
                }
            }
            
            // Saved Tab
            if authViewModel.isLoggedIn {
                TabButton(
                    icon: "heart.fill",
                    title: "Saved",
                    isSelected: selectedTab == 2,
                    count: marketplaceViewModel.getSavedItems().count
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = 2
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - Browse Content
    
    var browseContent: some View {
        Group {
            if marketplaceViewModel.isLoading && marketplaceViewModel.items.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: AppSpacing.md),
                        GridItem(.flexible(), spacing: AppSpacing.md)
                    ], spacing: AppSpacing.md) {
                        ForEach(0..<6, id: \.self) { _ in
                            SkeletonMarketplaceCard()
                        }
                    }
                    .padding(AppSpacing.md)
                }
            } else if filteredItems.isEmpty {
                VStack(spacing: AppSpacing.lg) {
                    Spacer()
                    
                    Image(systemName: "cart")
                        .font(.system(size: 80))
                        .foregroundColor(AppColors.textTertiary)
                    
                    VStack(spacing: 8) {
                        Text("No items found")
                            .font(AppFonts.title2)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Be the first to list something!")
                            .font(AppFonts.callout)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    if authViewModel.isLoggedIn {
                        Button(action: {
                            showingAddItem = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("List an Item")
                            }
                            .font(AppFonts.bodyBold)
                            .foregroundColor(.white)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.primary)
                            .cornerRadius(AppRadius.md)
                        }
                    }
                    
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: AppSpacing.md),
                        GridItem(.flexible(), spacing: AppSpacing.md)
                    ], spacing: AppSpacing.md) {
                        // Refresh indicator
                        if isRefreshing {
                            HStack {
                                Spacer()
                                ProgressView()
                                Text("Refreshing...")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                Spacer()
                            }
                            .padding(.vertical, AppSpacing.sm)
                            .gridCellColumns(2)
                        }
                        
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            NavigationLink(destination: MarketplaceDetailView(item: item, marketplaceViewModel: marketplaceViewModel)) {
                                MarketplaceItemCard(
                                    item: item,
                                    distance: locationManager.location != nil ? marketplaceViewModel.getDistance(to: item) : nil
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onAppear {
                                if index == filteredItems.count - 3 {
                                    marketplaceViewModel.loadMoreItems()
                                }
                            }
                        }
                        
                        // Loading more indicator
                        if marketplaceViewModel.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                Text("Loading more...")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                Spacer()
                            }
                            .padding(.vertical, AppSpacing.md)
                            .gridCellColumns(2)
                        }
                        
                        // End message
                        if !marketplaceViewModel.hasMoreData && !marketplaceViewModel.items.isEmpty {
                            Text("You've reached the end")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.textTertiary)
                                .padding(.vertical, AppSpacing.lg)
                                .gridCellColumns(2)
                        }
                    }
                    .padding(AppSpacing.md)
                }
                .refreshable {
                    await refreshData()
                }
            }
        }
    }
    
    // MARK: - My Listings Content
    
    var myListingsContent: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: AppSpacing.md),
                GridItem(.flexible(), spacing: AppSpacing.md)
            ], spacing: AppSpacing.md) {
                if marketplaceViewModel.getUserItems().isEmpty {
                    VStack(spacing: AppSpacing.lg) {
                        Spacer()
                        
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 80))
                            .foregroundColor(AppColors.textTertiary)
                        
                        VStack(spacing: 8) {
                            Text("No listings yet")
                                .font(AppFonts.title2)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("Start selling by adding your first item")
                                .font(AppFonts.callout)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: {
                            showingAddItem = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("List an Item")
                            }
                            .font(AppFonts.bodyBold)
                            .foregroundColor(.white)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.primary)
                            .cornerRadius(AppRadius.md)
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gridCellColumns(2)
                } else {
                    ForEach(marketplaceViewModel.getUserItems()) { item in
                        NavigationLink(destination: MarketplaceDetailView(item: item, marketplaceViewModel: marketplaceViewModel)) {
                            MarketplaceItemCard(
                                item: item,
                                distance: nil,
                                showActions: true
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(AppSpacing.md)
        }
    }
    
    // MARK: - Saved Items Content
    
    var savedItemsContent: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: AppSpacing.md),
                GridItem(.flexible(), spacing: AppSpacing.md)
            ], spacing: AppSpacing.md) {
                if marketplaceViewModel.getSavedItems().isEmpty {
                    VStack(spacing: AppSpacing.lg) {
                        Spacer()
                        
                        Image(systemName: "heart.circle")
                            .font(.system(size: 80))
                            .foregroundColor(AppColors.textTertiary)
                        
                        VStack(spacing: 8) {
                            Text("No saved items")
                                .font(AppFonts.title2)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("Save items you're interested in to find them easily")
                                .font(AppFonts.callout)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, AppSpacing.xl)
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gridCellColumns(2)
                } else {
                    ForEach(marketplaceViewModel.getSavedItems()) { item in
                        NavigationLink(destination: MarketplaceDetailView(item: item, marketplaceViewModel: marketplaceViewModel)) {
                            MarketplaceItemCard(
                                item: item,
                                distance: locationManager.location != nil ? marketplaceViewModel.getDistance(to: item) : nil
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(AppSpacing.md)
        }
    }
    
    // MARK: - Helper Functions
    
    func requestLocationIfNeeded() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestPermission()
        } else if locationManager.authorizationStatus == .authorizedWhenInUse ||
                  locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startUpdating()
        }
    }
    
    @MainActor
    func refreshData() async {
        isRefreshing = true
        marketplaceViewModel.refreshItems()
        
        while marketplaceViewModel.isLoading {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        isRefreshing = false
    }
}

// MARK: - Tab Button Component

struct TabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    var count: Int? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                    Text(title)
                        .font(AppFonts.callout)
                        .fontWeight(.semibold)
                    
                    // Show count badge if available
                    if let count = count, count > 0 {
                        Text("\(count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.primary)
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(isSelected ? AppColors.primary : AppColors.textSecondary)
                
                Rectangle()
                    .fill(isSelected ? AppColors.primary : Color.clear)
                    .frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Skeleton Marketplace Card

struct SkeletonMarketplaceCard: View {
    @State private var isAnimating = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image skeleton
            Rectangle()
                .fill(AppColors.surface.opacity(0.5))
                .frame(height: 140)
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.clear, Color.white.opacity(colorScheme == .dark ? 0.1 : 0.4), Color.clear]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: isAnimating ? 400 : -400)
                )
            
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(AppColors.surface.opacity(0.5))
                    .frame(height: 16)
                    .cornerRadius(4)
                
                Rectangle()
                    .fill(AppColors.surface.opacity(0.5))
                    .frame(height: 14)
                    .cornerRadius(4)
                
                Rectangle()
                    .fill(AppColors.surface.opacity(0.5))
                    .frame(width: 60, height: 12)
                    .cornerRadius(4)
            }
            .padding(AppSpacing.sm)
        }
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
        .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.small, radius: 4, x: 0, y: 2)
        .onAppear {
            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}
