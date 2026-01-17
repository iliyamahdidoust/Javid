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
    @State private var selectedTab = "browse" // browse, sell, categories
    @State private var showNearby = false
    @State private var scrollOffset: CGFloat = 0
    @State private var userCity: String = ""
    @State private var userProvince: String = ""
    
    @Environment(\.colorScheme) var colorScheme
    
    var filteredItems: [MarketplaceItem] {
        var items = marketplaceViewModel.items
        
        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }
        
        if showNearby, let userLocation = locationManager.location {
            items = items.sorted { item1, item2 in
                let distance1 = userLocation.distance(from: CLLocation(
                    latitude: item1.latitude,
                    longitude: item1.longitude
                ))
                let distance2 = userLocation.distance(from: CLLocation(
                    latitude: item2.latitude,
                    longitude: item2.longitude
                ))
                return distance1 < distance2
            }
        }
        
        return items
    }
    
    var userItems: [MarketplaceItem] {
        marketplaceViewModel.getUserItems()
    }
    
//    // Control visibility based on scroll
    var showTabsAndNearby: Bool {
        scrollOffset > -50
    }
    
//    var showCategories: Bool {
//        scrollOffset <= 0
//    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    // Browse/Sell/Categories - Small buttons on LEFT
                    if showTabsAndNearby {
                        tabButtonsSection
                    }
                    
                    // Nearby + Address Row
                    if selectedTab == "browse" && showTabsAndNearby {
                        nearbyWithAddressSection
                    }
                    
                    // Main Content with Scroll Detection
                    ScrollViewWithOffset(offset: $scrollOffset) {
                        VStack(spacing: 0) {
                            // Categories - Now INSIDE the ScrollView so it scrolls away
                            if selectedTab == "browse" {
                                categoriesSection
                                browseContent
                            } else if selectedTab == "sell" {
                                sellContent
                            } else {
                                allCategoriesContent
                            }
                        }
                    }
                    .refreshable {
                        await refreshData()
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddItem) {
                AddMarketplaceItemView(marketplaceViewModel: marketplaceViewModel)
            }
            .onAppear {
                requestLocationIfNeeded()
                if authViewModel.isLoggedIn {
                    marketplaceViewModel.fetchUserItems { _ in }
                }
            }
            .onChange(of: locationManager.location) { newLocation in
                if let location = newLocation {
                    reverseGeocodeLocation(location)
                }
            }
        }
    }

    
    // MARK: - Header Section
    
    var headerSection: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                Text("Marketplace")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button(action: {
                        // TODO: Navigate to messages
                    }) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundColor(AppColors.primary)
                    }
                    
                    NavigationLink(destination: MarketplaceSearchView(marketplaceViewModel: marketplaceViewModel)) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppColors.surface)
            
            Divider()
                .background(AppColors.border.opacity(0.3))
        }
    }
    
    // MARK: - Tab Buttons Section (Small buttons on LEFT)
    
    var tabButtonsSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                CompactTabButton(
                    title: "Browse",
                    isSelected: selectedTab == "browse"
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = "browse"
                    }
                }
                
                CompactTabButton(
                    title: "Sell",
                    isSelected: selectedTab == "sell"
                ) {
                    if authViewModel.isLoggedIn {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = "sell"
                        }
                    }
                }
                
                CompactTabButton(
                    title: "Categories",
                    isSelected: selectedTab == "categories"
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = "categories"
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppColors.surface)
            
            Divider()
                .background(AppColors.border.opacity(0.3))
        }
    }
    
    // MARK: - Nearby + Address Section
    
    var nearbyWithAddressSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Nearby Button (LEFT)
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showNearby.toggle()
                    }
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("Nearby")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(showNearby ? .white : AppColors.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        showNearby
                            ? LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(AppRadius.full)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.full)
                            .stroke(AppColors.primary, lineWidth: showNearby ? 0 : 1.5)
                    )
                    .shadow(
                        color: showNearby ? AppColors.primary.opacity(0.3) : Color.clear,
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                }
                
                Spacer()
                
                // User Address (RIGHT)
                if !userCity.isEmpty && !userProvince.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.primary)
                        
                        Text("\(userCity), \(userProvince)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.full)
                            .fill(AppColors.primary.opacity(0.1))
                    )
                } else if locationManager.location != nil {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading...")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppColors.surface)
            
            Divider()
                .background(AppColors.border.opacity(0.3))
        }
    }
    
    // MARK: - Categories Section
    
    var categoriesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                CategoryButton(
                    icon: "square.grid.2x2",
                    label: "All",
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedCategory = nil
                    }
                }
                
                ForEach(MarketplaceCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        icon: category.icon,
                        label: category.rawValue,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(AppColors.background)
    }
    
    // MARK: - Browse Content
    
    var browseContent: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 2),
                GridItem(.flexible(), spacing: 2)
            ],
            spacing: 2
        ) {
            if marketplaceViewModel.isLoading && marketplaceViewModel.items.isEmpty {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonMarketplaceCard()
                }
            } else if filteredItems.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "cart")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(AppColors.textTertiary)
                    
                    Text("No items found")
                        .font(AppFonts.title2)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Be the first to list something!")
                        .font(AppFonts.callout)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .gridCellColumns(2)
            } else {
                ForEach(filteredItems) { item in
                    NavigationLink(destination: MarketplaceDetailView(item: item, marketplaceViewModel: marketplaceViewModel)) {
                        FacebookStyleMarketplaceCard(
                            item: item,
                            distance: locationManager.location != nil ? marketplaceViewModel.getDistance(to: item) : nil
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Sell Content
    
    var sellContent: some View {
        NavigationLink(destination: SellerDashboardView(marketplaceViewModel: marketplaceViewModel)) {
            VStack(spacing: 24) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.12))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppColors.primary)
                }
                
                VStack(spacing: 12) {
                    Text("Seller Dashboard")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Manage your listings and track performance")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                HStack(spacing: 8) {
                    Text("Open Dashboard")
                        .font(.system(size: 17, weight: .semibold))
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing)
                )
                .cornerRadius(AppRadius.md)
                .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - All Categories Content
    
    var allCategoriesContent: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ],
            spacing: 16
        ) {
            ForEach(MarketplaceCategory.allCases, id: \.self) { category in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedCategory = category
                        selectedTab = "browse"
                    }
                }) {
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: category.color).opacity(0.15),
                                            Color(hex: category.color).opacity(0.25)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 100)
                            
                            Image(systemName: category.icon)
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(Color(hex: category.color))
                        }
                        
                        Text(category.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(20)
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
    
    func reverseGeocodeLocation(_ location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                if let city = placemark.locality {
                    userCity = city
                }
                
                if let province = placemark.administrativeArea {
                    userProvince = province
                }
            }
        }
    }
    
    @MainActor
    func refreshData() async {
        isRefreshing = true
        marketplaceViewModel.refreshItems()
        
        if authViewModel.isLoggedIn {
            marketplaceViewModel.fetchUserItems { _ in }
        }
        
        while marketplaceViewModel.isLoading {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        isRefreshing = false
    }
}

// MARK: - Compact Tab Button

struct CompactTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? AppColors.primary
                        : (colorScheme == .dark
                            ? Color(white: 0.2)
                            : Color(white: 0.95))
                )
                .cornerRadius(AppRadius.full)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? AppColors.primary.opacity(0.15)
                                : (colorScheme == .dark
                                    ? AppColors.surface
                                    : Color(white: 0.95))
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(isSelected ? AppColors.primary : AppColors.textPrimary)
                }
                
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? AppColors.primary : AppColors.textSecondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Facebook Style Marketplace Card

struct FacebookStyleMarketplaceCard: View {
    let item: MarketplaceItem
    var distance: Double?
    var showActions: Bool = false
    
    @State private var appeared = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if let firstPhotoURL = item.photoURLs.first,
                   let url = URL(string: firstPhotoURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                    } placeholder: {
                        ZStack {
                            Color(white: colorScheme == .dark ? 0.2 : 0.9)
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        .aspectRatio(1, contentMode: .fill)
                    }
                } else {
                    ZStack {
                        Color(white: colorScheme == .dark ? 0.2 : 0.9)
                        Image(systemName: item.category.icon)
                            .font(.system(size: 30, weight: .light))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .aspectRatio(1, contentMode: .fill)
                }
                
                if item.isSold {
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
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                Text(item.title)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: 36, alignment: .top)
                
                Text("\(item.location)\(distance != nil ? String(format: " (%.1f km)", distance!) : "")")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textTertiary)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                colorScheme == .dark
                    ? Color(white: 0.15)
                    : AppColors.surface
            )
        }
        .background(
            colorScheme == .dark
                ? Color(white: 0.15)
                : AppColors.surface
        )
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.95)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(Double.random(in: 0...0.05))) {
                appeared = true
            }
        }
    }
}

// MARK: - Skeleton Marketplace Card

struct SkeletonMarketplaceCard: View {
    @State private var isAnimating = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(1, contentMode: .fill)
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
            
            VStack(alignment: .leading, spacing: 6) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 16)
                    .frame(width: 80)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 14)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 12)
                    .frame(width: 100)
            }
            .padding(10)
        }
        .background(AppColors.surface)
        .onAppear {
            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - ScrollView with Offset Detection

struct ScrollViewWithOffset<Content: View>: View {
    @Binding var offset: CGFloat
    let content: () -> Content
    
    var body: some View {
        ScrollView {
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geometry.frame(in: .named("scroll")).minY
                    )
            }
            .frame(height: 0)
            
            content()
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            offset = value
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
