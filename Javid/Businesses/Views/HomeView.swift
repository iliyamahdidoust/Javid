import SwiftUI
import CoreLocation
import MapKit
import Combine


struct HomeView: View {
    // MARK: - Dependencies
    @ObservedObject var businessViewModel: BusinessViewModel
    @EnvironmentObject var favoriteViewModel: FavoriteViewModel
    @StateObject private var locationManager = LocationManager()
    
    // MARK: - UI State
    @State private var selectedCategory: String?
    @State private var viewMode: ViewMode = .card
    @State private var activeFilter: QuickFilter = .all
    @State private var sortBy: SortOption = .distance
    @State private var scrollOffset: CGFloat = 0
    @State private var headerOpacity: Double = 0
    @State private var showingMapView = false
    @State private var showSearchSheet = false
    @State private var showFilterSheet = false
    @State private var selectedBusiness: Business?
    @State private var isRefreshing = false
    @State private var showWelcomeAnimation = false
    @State private var showLocationPicker = false // NEW: For location selection
    @State private var hasUnreadNotifications = false // NEW: For notification badge
    
    // MARK: - Advanced Filters
    @State private var minRating: Double = 0
    @State private var maxDistance: Double = 50
    @State private var priceRange: Set<String> = []
    @State private var isOpenNowFilter: Bool = false
    @State private var hasAmenities: Set<String> = []
    
    @AppStorage("searchHistory") private var searchHistoryString: String = ""
    
    // MARK: - Enums
    enum ViewMode: String {
        case card = "Card"
        case list = "List"
        case grid = "Grid"
        
        var icon: String {
            switch self {
            case .card: return "rectangle.portrait.fill"
            case .list: return "list.bullet"
            case .grid: return "square.grid.2x2"
            }
        }
    }
    
    enum QuickFilter: String, CaseIterable {
        case all = "All"
        case openNow = "Open Now"
        case topRated = "Top Rated"
        case nearby = "Nearby"
        case trending = "Trending"
        case favorites = "Favorites"
        
        var icon: String {
            switch self {
            case .all: return "square.grid.2x2.fill"
            case .openNow: return "clock.fill"
            case .topRated: return "star.fill"
            case .nearby: return "location.fill"
            case .trending: return "flame.fill"
            case .favorites: return "heart.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .blue
            case .openNow: return .green
            case .topRated: return .orange
            case .nearby: return .purple
            case .trending: return .red
            case .favorites: return .pink
            }
        }
    }
    
    enum SortOption: String, CaseIterable {
        case distance = "Distance"
        case rating = "Rating"
        case reviewCount = "Most Reviewed"
        case newest = "Newest"
        case alphabetical = "A-Z"
        
        var icon: String {
            switch self {
            case .distance: return "location.circle.fill"
            case .rating: return "star.circle.fill"
            case .reviewCount: return "text.bubble.fill"
            case .newest: return "clock.fill"
            case .alphabetical: return "textformat.abc"
            }
        }
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // Premium Background
                backgroundView
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        // Hero Section with Parallax
                        heroSection
                            .offset(y: max(scrollOffset * 0.5, -100))
                            .opacity(1 - min(max(headerOpacity, 0), 0.5))
                            .zIndex(1)
                        
                        VStack(spacing: 24) {
                            
                            // Quick Action Cards
                            quickActionsSection
                            
                            // Smart Filter Chips
                            filterChipsSection
                            
                            // Featured Carousel
                            if !featuredBusinesses.isEmpty {
                                featuredCarousel
                            }
                            
                            // Recommended for You
                            if !recommendedBusinesses.isEmpty && activeFilter == .all {
                                recommendedSection
                            }
                            
                            // Category Grid
                            categorySection
                            
                            // Sort & View Controls
                            controlsSection
                            
                            // Main Business List
                            businessListSection
                            
                            // Load More
                            if businessViewModel.hasMoreData {
                                loadMoreSection
                            }
                        }
                        .padding(.top, 20)
                    }
                }
                .coordinateSpace(name: "scroll")
                .overlay(scrollTracker)
                .refreshable {
                    await performRefresh()
                }
                
                // Floating Action Button
                floatingActionButton
                
                // Loading Overlay
                if businessViewModel.isLoading && businessViewModel.businesses.isEmpty {
                    loadingOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    compactHeader
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    menuButton
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    trailingButtons
                }
            }
            .sheet(isPresented: $showingMapView) {
                advancedMapView
            }
            .sheet(isPresented: $showFilterSheet) {
                advancedFilterSheet
            }
            .sheet(isPresented: $showSearchSheet) {
                SearchView(businessViewModel: businessViewModel)
            }
            .sheet(item: $selectedBusiness) { business in
                BusinessDetailView(business: business)
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView(locationManager: locationManager)
            }
        }
        .onAppear {
            setupView()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                showWelcomeAnimation = true
            }
            checkForNotifications() // Check notification status
        }
    }
    
    // MARK: - Background View
    @ViewBuilder
    private var backgroundView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            AnimatedBackground()
                .ignoresSafeArea()
        }
    }
    
    // MARK: - Hero Section
    @ViewBuilder
    private var heroSection: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Discover")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(showWelcomeAnimation ? 1 : 0)
                        .offset(y: showWelcomeAnimation ? 0 : -20)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text(userLocationText)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "chevron.down.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .onTapGesture {
                        showLocationPicker = true
                        hapticFeedback(.medium)
                    }
                }
                
                Spacer()
                
//                profileAvatar
            }
            .padding(.horizontal, 20)
            .padding(.top, -60)
        }
        .background(Color(.systemBackground))
    }
    
//    @ViewBuilder
//    private var profileAvatar: some View {
//        Button(action: {
//            // Navigate to profile - implement navigation logic
//        }) {
//            ZStack {
//                Circle()
//                    .strokeBorder(
//                        LinearGradient(
//                            colors: [.blue, .purple],
//                            startPoint: .topLeading,
//                            endPoint: .bottomTrailing
//                        ),
//                        lineWidth: 3
//                    )
//                    .frame(width: 56, height: 56)
//
//                Circle()
//                    .fill(
//                        LinearGradient(
//                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
//                            startPoint: .topLeading,
//                            endPoint: .bottomTrailing
//                        )
//                    )
//                    .frame(width: 50, height: 50)
//
//                Image(systemName: "person.fill")
//                    .foregroundColor(.white)
//                    .font(.system(size: 20, weight: .semibold))
//            }
//            .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
//        }
//    }
    
    // MARK: - Quick Actions Section
    @ViewBuilder
    private var quickActionsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                QuickActionCard(
                    icon: "sparkles",
                    title: "AI Picks",
                    subtitle: "For You",
                    gradient: [.purple, .pink],
                    action: {
                        withAnimation(.spring(response: 0.3)) {
                            activeFilter = .trending
                            hapticFeedback(.medium)
                        }
                    }
                )
                
                QuickActionCard(
                    icon: "crown.fill",
                    title: "Top Rated",
                    subtitle: "Best Quality",
                    gradient: [.orange, .yellow],
                    action: {
                        withAnimation(.spring(response: 0.3)) {
                            activeFilter = .topRated
                            hapticFeedback(.medium)
                        }
                    }
                )
                
                QuickActionCard(
                    icon: "location.fill.viewfinder",
                    title: "Nearby",
                    subtitle: "Close to You",
                    gradient: [.blue, .cyan],
                    action: {
                        withAnimation(.spring(response: 0.3)) {
                            activeFilter = .nearby
                            hapticFeedback(.medium)
                        }
                    }
                )
                
                QuickActionCard(
                    icon: "clock.badge.checkmark",
                    title: "Open Now",
                    subtitle: "Visit Today",
                    gradient: [.green, .mint],
                    action: {
                        withAnimation(.spring(response: 0.3)) {
                            activeFilter = .openNow
                            hapticFeedback(.medium)
                        }
                    }
                )
                
                QuickActionCard(
                    icon: "heart.circle.fill",
                    title: "Favorites",
                    subtitle: "Your Picks",
                    gradient: [.pink, .red],
                    action: {
                        withAnimation(.spring(response: 0.3)) {
                            activeFilter = .favorites
                            hapticFeedback(.medium)
                        }
                    }
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .background(
                Color(.systemBackground)
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
            )
        }
    }
    // MARK: - Filter Chips Section
    @ViewBuilder
    private var filterChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(QuickFilter.allCases, id: \.self) { filter in
                    HomeFilterChip(
                        title: filter.rawValue,
                        icon: filter.icon,
                        isSelected: activeFilter == filter,
                        count: getFilterCount(filter),
                        action: {
                            withAnimation(.spring(response: 0.3)) {
                                activeFilter = filter
                                hapticFeedback()
                            }
                        }
                    )
                }
                
                if hasActiveAdvancedFilters {
                    HomeFilterChip(
                        title: "Filters",
                        icon: "slider.horizontal.3",
                        isSelected: true,
                        count: activeFiltersCount,
                        action: {
                            showFilterSheet = true
                            hapticFeedback()
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Featured Carousel
    @ViewBuilder
    private var featuredCarousel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.orange.opacity(0.2), .red.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "flame.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .font(.system(size: 20))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trending Now")
                            .font(.system(size: 20, weight: .bold))
                        Text("Most popular this week")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    activeFilter = .trending
                    hapticFeedback()
                }) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16))
                    }
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(featuredBusinesses.prefix(8)) { business in
                        PremiumBusinessCard(
                            business: business,
                            distance: distance(to: business),
                            isFavorite: favoriteViewModel.isFavorite(businessId: business.id ?? "")
                        ) {
                            selectedBusiness = business
                            hapticFeedback(.soft)
                        } onFavorite: {
                            toggleFavorite(business)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Recommended Section
    @ViewBuilder
    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .font(.system(size: 20))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recommended for You")
                            .font(.system(size: 20, weight: .bold))
                        Text("Based on your preferences")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(recommendedBusinesses.prefix(5)) { business in
                        PremiumBusinessCard(
                            business: business,
                            distance: distance(to: business),
                            isFavorite: favoriteViewModel.isFavorite(businessId: business.id ?? "")
                        ) {
                            selectedBusiness = business
                            hapticFeedback(.soft)
                        } onFavorite: {
                            toggleFavorite(business)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Category Section
    @ViewBuilder
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Categories")
                    .font(.system(size: 20, weight: .bold))
                    .padding(.leading, 20)
                
                Spacer()
                
                if selectedCategory != nil {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = nil
                            hapticFeedback()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text("Clear")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.trailing, 20)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CategoryChip(
                        title: "All",
                        isSelected: selectedCategory == nil,
                        icon: "square.grid.2x2"
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = nil
                            hapticFeedback()
                        }
                    }
                    
                    ForEach(availableCategories, id: \.self) { category in
                        CategoryChip(
                            title: category,
                            isSelected: selectedCategory == category,
                            icon: iconForCategory(category)
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedCategory = category
                                hapticFeedback()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Controls Section
    @ViewBuilder
    private var controlsSection: some View {
        HStack(spacing: 14) {
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(action: {
                        sortBy = option
                        hapticFeedback()
                    }) {
                        Label(
                            option.rawValue,
                            systemImage: sortBy == option ? "checkmark.circle.fill" : option.icon
                        )
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: sortBy.icon)
                        .font(.system(size: 14, weight: .semibold))
                    Text(sortBy.rawValue)
                        .font(.system(size: 15, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            
            Spacer()
            
            Text("\(filteredAndSortedBusinesses.count) results")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Button(action: cycleViewMode) {
                Image(systemName: viewMode.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.blue.opacity(0.1)))
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Business List Section
    @ViewBuilder
    private var businessListSection: some View {
        if filteredAndSortedBusinesses.isEmpty {
            emptyStateView
        } else {
            switch viewMode {
            case .card:
                cardLayoutView
            case .list:
                listLayoutView
            case .grid:
                gridLayoutView
            }
        }
    }
    
    @ViewBuilder
    private var cardLayoutView: some View {
        LazyVStack(spacing: 20) {
            ForEach(Array(filteredAndSortedBusinesses.enumerated()), id: \.element.id) { index, business in
                NavigationLink(destination: BusinessDetailView(business: business)) {
                    EnhancedBusinessCardView(
                        business: business,
                        distance: distance(to: business),
                        isFavorite: favoriteViewModel.isFavorite(businessId: business.id ?? ""),
                        onTap: {
                            selectedBusiness = business
                            hapticFeedback(.soft)
                        },
                        onCall: { callBusiness(business) },
                        onDirections: { openDirections(to: business) },
                        onShare: { shareBusiness(business) },
                        onFavorite: { toggleFavorite(business) }
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.03),
                    value: filteredAndSortedBusinesses.count
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 100)
    }
    
    @ViewBuilder
    private var listLayoutView: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredAndSortedBusinesses) { business in
                NavigationLink(destination: BusinessDetailView(business: business)) {
                    CompactListCard(
                        business: business,
                        distance: distance(to: business),
                        isFavorite: favoriteViewModel.isFavorite(businessId: business.id ?? ""),
                        onTap: {
                            selectedBusiness = business
                            hapticFeedback(.soft)
                        },
                        onFavorite: { toggleFavorite(business) }
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 100)
    }
    
    @ViewBuilder
    private var gridLayoutView: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ],
            spacing: 16
        ) {
            ForEach(filteredAndSortedBusinesses) { business in
                NavigationLink(destination: BusinessDetailView(business: business)) {
                    CompactBusinessCard(
                        business: business,
                        distance: distance(to: business),
                        isFavorite: favoriteViewModel.isFavorite(businessId: business.id ?? ""),
                        onTap: {
                            selectedBusiness = business
                            hapticFeedback(.soft)
                        },
                        onFavorite: { toggleFavorite(business) }
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 100)
    }
    
    // MARK: - Load More Section
    @ViewBuilder
    private var loadMoreSection: some View {
        VStack(spacing: 16) {
            if businessViewModel.isLoadingMore {
                ProgressView()
                    .scaleEffect(1.0)
                    .tint(.blue)
                    .padding()
            } else if filteredAndSortedBusinesses.count >= 20 {
                Button(action: {
                    businessViewModel.loadMoreBusinesses()
                    hapticFeedback(.soft)
                }) {
                    Text("Load More")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(.vertical, 10)
    }
    
    // MARK: - Empty State
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 28) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("No Results Found")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Try adjusting your filters or\nexplore different categories")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Button(action: resetFilters) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 18))
                    Text("Reset Filters")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: .blue.opacity(0.3), radius: 12, y: 6)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Scroll Tracker
    @ViewBuilder
    private var scrollTracker: some View {
        GeometryReader { geometry in
            Color.clear.preference(
                key: HomeScrollOffsetPreferenceKey.self,
                value: geometry.frame(in: .named("scroll")).minY
            )
        }
        .onPreferenceChange(HomeScrollOffsetPreferenceKey.self) { value in
            scrollOffset = value
            withAnimation(.easeInOut(duration: 0.2)) {
                headerOpacity = min(max(-value / 100, 0), 1)
            }
        }
    }
    
    // MARK: - Compact Header
    @ViewBuilder
    private var compactHeader: some View {
        VStack(spacing: 2) {
            Text("Discover")
                .font(.headline)
                .fontWeight(.bold)
            Text(userLocationText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .opacity(headerOpacity)
    }
    
    // MARK: - Menu Button
    @ViewBuilder
    private var menuButton: some View {
        Menu {
            Button(action: { showSearchSheet.toggle() }) {
                Label("Search", systemImage: "magnifyingglass")
            }
            Button(action: { showFilterSheet.toggle() }) {
                Label("Filters", systemImage: "slider.horizontal.3")
            }
            Button(action: { showingMapView.toggle() }) {
                Label("Map View", systemImage: "map")
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 20))
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Trailing Buttons
    @ViewBuilder
    private var trailingButtons: some View {
        HStack(spacing: 16) {
            Button(action: toggleViewMode) {
                Image(systemName: viewModeIcon)
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
            }
            
            NavigationLink(destination: NotificationView(hasUnreadNotifications: $hasUnreadNotifications)) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                    
                    // Only show badge if there are unread notifications
                    if hasUnreadNotifications {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 4, y: -4)
                    }
                }
            }
        }
    }
    
    // MARK: - Floating Action Button
    @ViewBuilder
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    showingMapView.toggle()
                    hapticFeedback(.medium)
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .shadow(color: .blue.opacity(0.4), radius: 12, y: 6)
                        
                        Image(systemName: "map.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Loading Overlay
    @ViewBuilder
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.blue)
                
                VStack(spacing: 8) {
                    Text("Discovering Places")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Finding the best spots for you...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 20)
            )
        }
    }
    
    // MARK: - Advanced Map View
    @ViewBuilder
    private var advancedMapView: some View {
        AdvancedMapView(
            businesses: filteredAndSortedBusinesses,
            userLocation: locationManager.location
        )
    }
    
    // MARK: - Advanced Filter Sheet
    @ViewBuilder
    private var advancedFilterSheet: some View {
        AdvancedFilterSheet(
            minRating: $minRating,
            maxDistance: $maxDistance,
            priceRange: $priceRange,
            isOpenNow: $isOpenNowFilter,
            onApply: applyFilters
        )
    }
}

// MARK: - HomeView Extension - Logic & Computed Properties
extension HomeView {
    
    // MARK: - Computed Properties
    
    // FIX 1: Real user location instead of placeholder
    private var userLocationText: String {
        if let location = locationManager.location {
            return locationManager.cityName ?? "Getting location..."
        } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
            return "Location Access Denied"
        } else {
            return "Getting location..."
        }
    }
    
    private var totalBusinessCount: Int {
        businessViewModel.businesses.count
    }
    
    private var averageRating: Double {
        guard !businessViewModel.businesses.isEmpty else { return 0 }
        let total = businessViewModel.businesses.reduce(0.0) { $0 + $1.rating }
        return total / Double(businessViewModel.businesses.count)
    }
    
    private var openNowCount: Int {
        businessViewModel.businesses.filter { isBusinessOpen($0) }.count
    }
    
    private var nearbyCount: Int {
        guard let userLocation = locationManager.location else { return 0 }
        return businessViewModel.businesses.filter { business in
            let businessLocation = CLLocation(latitude: business.latitude, longitude: business.longitude)
            return userLocation.distance(from: businessLocation) <= 5000
        }.count
    }
    
    private var availableCategories: [String] {
        Array(Set(businessViewModel.businesses.map { $0.category })).sorted()
    }
    
    private var featuredBusinesses: [Business] {
        businessViewModel.businesses
            .filter { $0.rating >= 4.5 && $0.reviewCount >= 10 }
            .sorted { $0.reviewCount > $1.reviewCount }
    }
    
    private var recommendedBusinesses: [Business] {
        let favoriteBusinesses = favoriteViewModel.favorites.compactMap { fav in
            businessViewModel.businesses.first { $0.id == fav.businessId }
        }
        
        let favoriteCategories = Set(favoriteBusinesses.map { $0.category })
        
        return businessViewModel.businesses
            .filter { business in
                favoriteCategories.contains(business.category) &&
                business.rating >= 4.0 &&
                !favoriteViewModel.isFavorite(businessId: business.id ?? "")
            }
            .sorted { $0.rating > $1.rating }
            .prefix(10)
            .map { $0 }
    }
    
    private var filteredAndSortedBusinesses: [Business] {
        var businesses = businessViewModel.businesses
        
        // Category filter
        if let category = selectedCategory {
            businesses = businesses.filter { $0.category == category }
        }
        
        // Advanced Filters
        if minRating > 0 {
            businesses = businesses.filter { $0.rating >= minRating }
        }
        
        if let userLocation = locationManager.location {
            businesses = businesses.filter { business in
                let businessLocation = CLLocation(latitude: business.latitude, longitude: business.longitude)
                let distanceInKm = userLocation.distance(from: businessLocation) / 1000
                return distanceInKm <= maxDistance
            }
        }
        
        if isOpenNowFilter {
            businesses = businesses.filter { isBusinessOpen($0) }
        }
        
        if !hasAmenities.isEmpty {
            businesses = businesses.filter { business in
                guard let businessAmenities = business.amenities else { return false }
                return hasAmenities.isSubset(of: businessAmenities)
            }
        }
        
        // Quick Filters
        switch activeFilter {
        case .all:
            break
        case .openNow:
            businesses = businesses.filter { isBusinessOpen($0) }
        case .topRated:
            businesses = businesses.filter { $0.rating >= 4.5 }
        case .nearby:
            if let userLocation = locationManager.location {
                businesses = businesses.filter { business in
                    let businessLocation = CLLocation(latitude: business.latitude, longitude: business.longitude)
                    return userLocation.distance(from: businessLocation) <= 5000
                }
            }
        case .trending:
            businesses = businesses
                .filter { $0.rating >= 4.0 && $0.reviewCount >= 5 }
                .sorted { $0.reviewCount > $1.reviewCount }
        case .favorites:
            let favoriteIds = favoriteViewModel.favorites.map { $0.businessId }
            businesses = businesses.filter { business in
                favoriteIds.contains(business.id ?? "")
            }
        }
        
        // Sorting
        switch sortBy {
        case .distance:
            if let userLocation = locationManager.location {
                businesses.sort { business1, business2 in
                    let loc1 = CLLocation(latitude: business1.latitude, longitude: business1.longitude)
                    let loc2 = CLLocation(latitude: business2.latitude, longitude: business2.longitude)
                    return userLocation.distance(from: loc1) < userLocation.distance(from: loc2)
                }
            }
        case .rating:
            businesses.sort { $0.rating > $1.rating }
        case .reviewCount:
            businesses.sort { $0.reviewCount > $1.reviewCount }
        case .newest:
            businesses.reverse()
        case .alphabetical:
            businesses.sort { $0.name < $1.name }
        }
        
        return businesses
    }
    
    private var hasActiveAdvancedFilters: Bool {
        minRating > 0 || maxDistance < 50 || !priceRange.isEmpty || isOpenNowFilter || !hasAmenities.isEmpty
    }
    
    private var activeFiltersCount: Int {
        var count = 0
        if minRating > 0 { count += 1 }
        if maxDistance < 50 { count += 1 }
        if !priceRange.isEmpty { count += 1 }
        if isOpenNowFilter { count += 1 }
        if !hasAmenities.isEmpty { count += 1 }
        return count
    }
    
    private var viewModeIcon: String {
        viewMode.icon
    }
    
    // MARK: - Helper Functions
    
    private func setupView() {
        if businessViewModel.businesses.isEmpty {
            businessViewModel.fetchBusinesses()
        }
        locationManager.requestPermission()
        locationManager.startUpdating()
    }
    
    // FIX 3: Check for unread notifications
    private func checkForNotifications() {
        // TODO: Replace this with your actual notification checking logic
        // This could be a call to your backend API or a local notification manager
        // For example:
        // NotificationManager.shared.hasUnreadNotifications { hasUnread in
        //     hasUnreadNotifications = hasUnread
        // }
        
        // Placeholder implementation - replace with your actual logic
        hasUnreadNotifications = false // Set to false by default
    }
    
    @MainActor
    private func performRefresh() async {
        isRefreshing = true
        
        businessViewModel.refreshBusinesses()
        favoriteViewModel.fetchUserFavorites()
        locationManager.startUpdating()
        checkForNotifications() // Refresh notification status
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        isRefreshing = false
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func distance(to business: Business) -> Double? {
        guard let userLocation = locationManager.location else { return nil }
        let businessLocation = CLLocation(latitude: business.latitude, longitude: business.longitude)
        return userLocation.distance(from: businessLocation) / 1000
    }
    
    private func isBusinessOpen(_ business: Business) -> Bool {
        guard let workHours = business.workHours else { return false }
        
        let weekday = Calendar.current.component(.weekday, from: Date())
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let currentTime = timeFormatter.string(from: Date())
        
        let dayHours: DayHours
        switch weekday {
        case 1: dayHours = workHours.sunday
        case 2: dayHours = workHours.monday
        case 3: dayHours = workHours.tuesday
        case 4: dayHours = workHours.wednesday
        case 5: dayHours = workHours.thursday
        case 6: dayHours = workHours.friday
        case 7: dayHours = workHours.saturday
        default: return false
        }
        
        return dayHours.isOpen && currentTime >= dayHours.openTime && currentTime <= dayHours.closeTime
    }
    
    private func iconForCategory(_ category: String) -> String {
        let icons: [String: String] = [
            "Restaurant": "fork.knife",
            "Cafe": "cup.and.saucer.fill",
            "Shop": "bag.fill",
            "Store": "cart.fill",
            "Gym": "figure.run",
            "Salon": "scissors",
            "Hospital": "cross.case.fill",
            "Doctor": "stethoscope",
            "Hotel": "bed.double.fill",
            "Bar": "wineglass.fill",
            "Spa": "sparkles",
            "Cinema": "film.fill",
            "Park": "leaf.fill",
            "Museum": "building.columns.fill",
            "Services": "wrench.and.screwdriver",
            "Lawyer": "briefcase.fill"
        ]
        return icons[category] ?? "star.fill"
    }
    
    private func getFilterCount(_ filter: QuickFilter) -> Int {
        switch filter {
        case .all: return businessViewModel.businesses.count
        case .openNow: return openNowCount
        case .topRated: return businessViewModel.businesses.filter { $0.rating >= 4.5 }.count
        case .nearby: return nearbyCount
        case .trending: return featuredBusinesses.count
        case .favorites: return favoriteViewModel.favorites.count
        }
    }
    
    private func toggleViewMode() {
        withAnimation(.spring(response: 0.3)) {
            switch viewMode {
            case .card: viewMode = .list
            case .list: viewMode = .grid
            case .grid: viewMode = .card
            }
            hapticFeedback()
        }
    }
    
    private func cycleViewMode() {
        toggleViewMode()
    }
    
    private func resetFilters() {
        withAnimation(.spring(response: 0.3)) {
            selectedCategory = nil
            activeFilter = .all
            minRating = 0
            maxDistance = 50
            priceRange = []
            isOpenNowFilter = false
            hasAmenities = []
            sortBy = .distance
            hapticFeedback(.medium)
        }
    }
    
    private func applyFilters() {
        showFilterSheet = false
        hapticFeedback(.medium)
    }
    
    private func toggleFavorite(_ business: Business) {
        guard let businessId = business.id else { return }
        hapticFeedback(.medium)
        
        favoriteViewModel.toggleFavorite(businessId: businessId) { success, message in
            if !success {
                print("Error: \(message)")
            }
        }
    }
    
    private func callBusiness(_ business: Business) {
        if let url = URL(string: "tel://\(business.phone.replacingOccurrences(of: " ", with: ""))") {
            UIApplication.shared.open(url)
        }
        hapticFeedback(.medium)
    }
    
    private func openDirections(to business: Business) {
        let mapItem = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: business.latitude, longitude: business.longitude)
        ))
        mapItem.name = business.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
        hapticFeedback(.medium)
    }
    
    private func shareBusiness(_ business: Business) {
        let text = """
        Check out \(business.name)!
        
        ⭐ \(String(format: "%.1f", business.rating)) (\(business.reviewCount) reviews)
        📍 \(business.address), \(business.city)
        📞 \(business.phone)
        
        Category: \(business.category)
        """
        
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootViewController.view
            rootViewController.present(activityVC, animated: true)
        }
        hapticFeedback(.medium)
    }
    
    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - Supporting Views

struct AnimatedBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemGray6).opacity(0.3),
                Color(.systemBackground)
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

struct HomeStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(16)
            .frame(width: 200)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct HomeFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("(\(count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color(.systemGray6)
                    }
                }
            )
            .cornerRadius(20)
            .shadow(
                color: isSelected ? Color.blue.opacity(0.3) : Color.clear,
                radius: 8,
                y: 4
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct PremiumBusinessCard: View {
    let business: Business
    let distance: Double?
    let isFavorite: Bool
    let onTap: () -> Void
    let onFavorite: () -> Void
    
    @State private var imageLoaded = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Image with gradient overlay
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: URL(string: business.photoURLs.first ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .onAppear { imageLoaded = true }
                        case .failure(_):
                            placeholderImage
                        case .empty:
                            placeholderImage
                        @unknown default:
                            placeholderImage
                        }
                    }
                    .frame(width: 300, height: 200)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Favorite Button
                    Button(action: onFavorite) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 18))
                                .foregroundColor(isFavorite ? .red : .white)
                        }
                    }
                    .padding(12)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 10) {
                    Text(business.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        // Rating
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(String(format: "%.1f", business.rating))
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("(\(business.reviewCount))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Distance
                        if let distance = distance {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(formatDistance(distance))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Category & Status
                    HStack(spacing: 8) {
                        Text(business.category)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        
                        if let workHours = business.workHours, isBusinessOpen(business, workHours) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text("Open")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(14)
            }
            .frame(width: 300)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var placeholderImage: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(.white.opacity(0.5))
            }
    }
    
    private func formatDistance(_ distance: Double) -> String {
        distance < 1000 ? String(format: "%.0f m", distance) : String(format: "%.1f km", distance / 1000)
    }
}

// MARK: - Additional Supporting Views

struct LottieLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(lineWidth: 3)
                    .frame(width: 60, height: 60)
                    .foregroundColor(.blue.opacity(0.3))
                    .scaleEffect(isAnimating ? 1.5 : 0.5)
                    .opacity(isAnimating ? 0 : 1)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct LottieEmptyStateView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 2)
                .frame(width: 100, height: 100)
                .foregroundColor(.gray.opacity(0.3))
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
                .scaleEffect(isAnimating ? 1.1 : 0.9)
                .animation(
                    Animation.easeInOut(duration: 1)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Scroll Offset Preference Key
struct HomeScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Advanced Filter Sheet
struct AdvancedFilterSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var minRating: Double
    @Binding var maxDistance: Double
    @Binding var priceRange: Set<String>
    @Binding var isOpenNow: Bool
    let onApply: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Rating")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Minimum Rating")
                            Spacer()
                            Text(String(format: "%.1f", minRating))
                                .fontWeight(.bold)
                        }
                        
                        Slider(value: $minRating, in: 0...5, step: 0.5)
                            .tint(.blue)
                        
                        HStack {
                            ForEach(0..<5) { index in
                                Image(systemName: "star.fill")
                                    .foregroundColor(Double(index) < minRating ? .orange : .gray.opacity(0.3))
                            }
                        }
                    }
                }
                
                Section(header: Text("Distance")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Maximum Distance")
                            Spacer()
                            Text("\(Int(maxDistance)) km")
                                .fontWeight(.bold)
                        }
                        
                        Slider(value: $maxDistance, in: 1...50, step: 1)
                            .tint(.blue)
                    }
                }
                
                Section(header: Text("Price Range")) {
                    HStack(spacing: 12) {
                        ForEach(["$", "$$", "$$$", "$$$$"], id: \.self) { price in
                            Button(action: {
                                if priceRange.contains(price) {
                                    priceRange.remove(price)
                                } else {
                                    priceRange.insert(price)
                                }
                            }) {
                                Text(price)
                                    .fontWeight(.semibold)
                                    .foregroundColor(priceRange.contains(price) ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        priceRange.contains(price)
                                            ? LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                                            : LinearGradient(colors: [Color(.systemGray5)], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                
                Section {
                    Toggle(isOn: $isOpenNow) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.green)
                            Text("Open Now Only")
                        }
                    }
                    .tint(.blue)
                }
                
                Section {
                    Button(action: {
                        minRating = 0
                        maxDistance = 50
                        priceRange = []
                        isOpenNow = false
                    }) {
                        HStack {
                            Spacer()
                            Text("Reset All Filters")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Advanced Map View
struct AdvancedMapView: View {
    let businesses: [Business]
    let userLocation: CLLocation?
    @Environment(\.dismiss) var dismiss
    @State private var region: MKCoordinateRegion
    @State private var selectedBusiness: Business?
    
    init(businesses: [Business], userLocation: CLLocation?) {
        self.businesses = businesses
        self.userLocation = userLocation
        
        if let location = userLocation {
            _region = State(initialValue: MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        } else if let first = businesses.first {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        } else {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Map(coordinateRegion: $region, annotationItems: businesses) { business in
                    MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: business.latitude, longitude: business.longitude)) {
                        Button(action: {
                            withAnimation {
                                selectedBusiness = business
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 40, height: 40)
                                    .shadow(color: .blue.opacity(0.4), radius: 8)
                                
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            .scaleEffect(selectedBusiness?.id == business.id ? 1.2 : 1.0)
                        }
                    }
                }
                .ignoresSafeArea()
                
                if let selected = selectedBusiness {
                    VStack {
                        Spacer()
                        BusinessMapPreview(business: selected) {
                            withAnimation {
                                selectedBusiness = nil
                            }
                        }
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                
                // Controls
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Button(action: {
                                if let location = userLocation {
                                    withAnimation {
                                        region.center = location.coordinate
                                    }
                                }
                            }) {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        Image(systemName: "location.fill")
                                            .foregroundColor(.blue)
                                    }
                                    .shadow(radius: 4)
                            }
                            
                            Button(action: {
                                withAnimation {
                                    region.span = MKCoordinateSpan(
                                        latitudeDelta: region.span.latitudeDelta * 0.5,
                                        longitudeDelta: region.span.longitudeDelta * 0.5
                                    )
                                }
                            }) {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        Image(systemName: "plus")
                                            .foregroundColor(.primary)
                                    }
                                    .shadow(radius: 4)
                            }
                            
                            Button(action: {
                                withAnimation {
                                    region.span = MKCoordinateSpan(
                                        latitudeDelta: min(region.span.latitudeDelta * 2, 1.0),
                                        longitudeDelta: min(region.span.longitudeDelta * 2, 1.0)
                                    )
                                }
                            }) {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        Image(systemName: "minus")
                                            .foregroundColor(.primary)
                                    }
                                    .shadow(radius: 4)
                            }
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
            .navigationTitle("Map View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct BusinessMapPreview: View {
    let business: Business
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: business.photoURLs.first ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(.white.opacity(0.5))
                        }
                }
            }
            .frame(width: 80, height: 80)
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(business.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(String(format: "%.1f", business.rating))
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("(\(business.reviewCount))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(business.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                NavigationLink(destination: BusinessDetailView(business: business)) {
                    Text("View Details")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
        )
    }
}




import SwiftUI
import MapKit
import Combine

// MARK: - Main Location Picker (First Screen - Popup)
struct LocationPickerView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var locationManager: LocationManager
    @StateObject private var viewModel = LocationPickerViewModel()
    @State private var showAdvancedSearch = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text("Choose a location")
                        .font(.system(size: 17, weight: .semibold))
                    
                    Spacer()
                    
                    // Invisible spacer for centering
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Current Location Card
                        currentLocationCard
                        
                        // Search Button
                        searchButton
                        
                        // Recent Locations
                        if !viewModel.recentLocations.isEmpty {
                            recentLocationsSection
                        }
                        
                        // Suggested Locations
                        suggestedLocationsSection
                    }
                    .padding(.vertical, 24)
                }
            }
            .background(Color(.systemBackground))
        }
        .fullScreenCover(isPresented: $showAdvancedSearch) {
            AdvancedLocationSearchView(
                locationManager: locationManager,
                viewModel: viewModel
            )
        }
        .onAppear {
            viewModel.locationManager = locationManager
            viewModel.loadRecentLocations()
        }
    }
    
    // MARK: - Current Location Card
    @ViewBuilder
    private var currentLocationCard: some View {
        Button(action: {
            locationManager.requestPermission()
            locationManager.startUpdating()
            // Set to normal radius (50km)
            locationManager.searchRadius = 50
            dismiss()
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Locate me")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Use my current location")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
    }
    
    // MARK: - Search Button
    @ViewBuilder
    private var searchButton: some View {
        Button(action: { showAdvancedSearch = true }) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                
                Text("Search by city, neighborhood or ZIP code")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
    }
    
    // MARK: - Recent Locations Section
    @ViewBuilder
    private var recentLocationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent locations")
                    .font(.system(size: 20, weight: .bold))
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                ForEach(Array(viewModel.recentLocations.prefix(5).enumerated()), id: \.element.id) { index, location in
                    LocationRow(
                        icon: "clock",
                        title: location.name,
                        showDivider: index < min(4, viewModel.recentLocations.count - 1)
                    ) {
                        viewModel.selectLocation(location)
                        dismiss()
                    }
                }
            }
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Suggested Locations Section
    @ViewBuilder
    private var suggestedLocationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested for you")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.suggestedLocations, id: \.id) { location in
                        SuggestedLocationChip(location: location) {
                            viewModel.selectLocation(location)
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Advanced Location Search View (Second Screen - Full Screen)
struct AdvancedLocationSearchView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var viewModel: LocationPickerViewModel
    
    @StateObject private var searchViewModel = LocationSearchViewModel()
    @StateObject private var mapViewModel = InteractiveMapViewModel()
    
    @State private var selectedRadius: Double = 50
    @State private var displayRadius: Double = 50 // For display only
    @State private var useCustomRadius = false
    @State private var isSearchFocused = false
    
    let normalRadius: Double = 50.0 // Normal radius in kilometers
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Search Bar
                    searchBar
                    
                    if !isSearchFocused && searchViewModel.searchText.isEmpty {
                        // Interactive Map and Radius Selection
                        VStack(spacing: 0) {
                            interactiveMap
                            
                            ScrollView {
                                radiusSelection
                                    .padding(.bottom, 100) // Space for apply button
                            }
                        }
                        .overlay(alignment: .bottom) {
                            // Apply Button (floating)
                            applyButton
                                .background(Color(.systemBackground))
                        }
                    } else {
                        // Search Results
                        searchResults
                    }
                }
                .navigationBarHidden(true)
            }
        }
        .onAppear {
            searchViewModel.locationManager = locationManager
            if let location = locationManager.location {
                mapViewModel.centerCoordinate = location.coordinate
            }
            displayRadius = selectedRadius
        }
    }
    
    // MARK: - Search Bar
    @ViewBuilder
    private var searchBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: {
                    if isSearchFocused || !searchViewModel.searchText.isEmpty {
                        searchViewModel.searchText = ""
                        searchViewModel.clearResults()
                        isSearchFocused = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    } else {
                        dismiss()
                    }
                }) {
                    Image(systemName: isSearchFocused || !searchViewModel.searchText.isEmpty ? "arrow.left" : "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                    
                    TextField("Search by city, neighborhood or ZIP code", text: $searchViewModel.searchText, onEditingChanged: { editing in
                        isSearchFocused = editing
                    })
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocapitalization(.none)
                    
                    if !searchViewModel.searchText.isEmpty {
                        Button(action: {
                            searchViewModel.searchText = ""
                            searchViewModel.clearResults()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
        }
    }
    
    // MARK: - Interactive Map
    @ViewBuilder
    private var interactiveMap: some View {
        ZStack {
            // Map View with gesture support
            InteractiveMapView(
                viewModel: mapViewModel,
                radius: useCustomRadius ? displayRadius : normalRadius
            )
            .frame(height: 400)
            
            // Center Pin with Circle (fixed in middle)
            VStack {
                Spacer()
                
                ZStack {
                    // Radius circle attached to pointer
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        .fill(Color.blue.opacity(0.1))
                        .frame(
                            width: calculateCircleSize(),
                            height: calculateCircleSize()
                        )
                    
                    // Center dot
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 20, height: 20)
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 20, height: 20)
                    }
                    .shadow(color: .black.opacity(0.3), radius: 4)
                }
                
                Spacer()
            }
            .allowsHitTesting(false)
        }
    }
    
    // Calculate circle size based on map zoom level
    private func calculateCircleSize() -> CGFloat {
        let radius = useCustomRadius ? displayRadius : normalRadius
        // Map radius (km) to screen size - adjust multiplier as needed
        let baseSize: CGFloat = 200.0
        let scale = radius / 50.0 // 50km is our baseline
        return baseSize * CGFloat(scale)
    }
    
    // MARK: - Radius Selection
    @ViewBuilder
    private var radiusSelection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Suggested radius option
            RadioButton(
                isSelected: !useCustomRadius,
                title: "Suggested local radius",
                subtitle: "Show me listings from this general area."
            ) {
                useCustomRadius = false
            }
            
            // Custom radius option
            RadioButton(
                isSelected: useCustomRadius,
                title: "Custom local radius",
                subtitle: "Only show me listings within a specific distance."
            ) {
                useCustomRadius = true
            }
            
            if useCustomRadius {
                VStack(alignment: .leading, spacing: 16) {
                    // Slider with labels
                    VStack(spacing: 8) {
                        HStack {
                            Text("1 km")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("100 km")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $selectedRadius, in: 1...100, step: 1) { editing in
                            if !editing {
                                // Update display radius when user finishes dragging
                                displayRadius = selectedRadius
                            }
                        }
                        .tint(.blue)
                        .onChange(of: selectedRadius) { newValue in
                            // Throttled update - only update every 5km to reduce lag
                            if abs(newValue - displayRadius) >= 5 || newValue == 1 || newValue == 100 {
                                displayRadius = newValue
                            }
                        }
                    }
                    
                    // Current radius display
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kilometers")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(Int(selectedRadius))")
                            .font(.system(size: 28, weight: .regular))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Search Results
    @ViewBuilder
    private var searchResults: some View {
        if searchViewModel.isSearching {
            VStack(spacing: 16) {
                ProgressView()
                Text("Searching...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxHeight: .infinity)
        } else if searchViewModel.searchResults.isEmpty && !searchViewModel.searchText.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 50))
                    .foregroundColor(.gray.opacity(0.5))
                Text("No results found")
                    .font(.headline)
            }
            .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(searchViewModel.searchResults, id: \.self) { completion in
                        Button(action: {
                            searchViewModel.selectLocation(completion) { success, coordinate in
                                if success, let coord = coordinate {
                                    mapViewModel.centerCoordinate = coord
                                    searchViewModel.searchText = ""
                                    searchViewModel.clearResults()
                                    isSearchFocused = false
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(completion.title)
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                    
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle)
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if completion != searchViewModel.searchResults.last {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Apply Button
    @ViewBuilder
    private var applyButton: some View {
        Button(action: {
            // Update location with selected coordinate and radius
            let coordinate = mapViewModel.centerCoordinate
            locationManager.updateLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                cityName: "" 
            )
            locationManager.searchRadius = useCustomRadius ? selectedRadius : normalRadius
            
            // Dismiss both sheets
            dismiss()
        }) {
            Text("Apply")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.blue)
                .cornerRadius(8)
        }
        .padding(20)
    }
}

// MARK: - Interactive Map View
struct InteractiveMapView: UIViewRepresentable {
    @ObservedObject var viewModel: InteractiveMapViewModel
    let radius: Double
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsUserLocation = false
        
        // Add gesture recognizers
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(panGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region based on center coordinate and radius
        let region = MKCoordinateRegion(
            center: viewModel.centerCoordinate,
            latitudinalMeters: radius * 2000,
            longitudinalMeters: radius * 2000
        )
        
        mapView.setRegion(region, animated: false) // Changed to false for smoother performance
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: InteractiveMapView
        
        init(_ parent: InteractiveMapView) {
            self.parent = parent
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            
            if gesture.state == .changed {
                let translation = gesture.translation(in: mapView)
                
                // Convert pixel translation to coordinate translation
                let pointsPerDegree = mapView.frame.width / mapView.region.span.longitudeDelta
                let latitudeDelta = -Double(translation.y) / pointsPerDegree
                let longitudeDelta = -Double(translation.x) / pointsPerDegree
                
                parent.viewModel.centerCoordinate = CLLocationCoordinate2D(
                    latitude: parent.viewModel.centerCoordinate.latitude + latitudeDelta,
                    longitude: parent.viewModel.centerCoordinate.longitude + longitudeDelta
                )
                
                gesture.setTranslation(.zero, in: mapView)
            }
        }
        
        // Allow simultaneous gestures for pinch zoom
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}

// MARK: - Interactive Map View Model
class InteractiveMapViewModel: ObservableObject {
    @Published var centerCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)
}

// MARK: - Supporting Views

struct LocationRow: View {
    let icon: String
    let title: String
    let showDivider: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    
                    Text(title)
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if showDivider {
                Divider()
                    .padding(.leading, 56)
            }
        }
    }
}

struct SuggestedLocationChip: View {
    let location: SavedLocation
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle")
                    .font(.system(size: 16))
                
                Text(location.name)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RadioButton: View {
    let isSelected: Bool
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Models

struct SavedLocation: Identifiable, Codable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    
    init(id: String = UUID().uuidString, name: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - View Models

class LocationPickerViewModel: ObservableObject {
    @Published var recentLocations: [SavedLocation] = []
    @Published var suggestedLocations: [SavedLocation] = [
        SavedLocation(name: "Toronto, Ontario", latitude: 43.6532, longitude: -79.3832),
        SavedLocation(name: "Hamilton, Ontario", latitude: 43.2557, longitude: -79.8711),
        SavedLocation(name: "Mississauga, Ontario", latitude: 43.5890, longitude: -79.6441),
        SavedLocation(name: "Brampton, Ontario", latitude: 43.7315, longitude: -79.7624),
        SavedLocation(name: "Markham, Ontario", latitude: 43.8561, longitude: -79.3370)
    ]
    
    var locationManager: LocationManager?
    
    private let recentLocationsKey = "recentLocations"
    
    func loadRecentLocations() {
        if let data = UserDefaults.standard.data(forKey: recentLocationsKey),
           let locations = try? JSONDecoder().decode([SavedLocation].self, from: data) {
            recentLocations = locations
        }
    }
    
    func selectLocation(_ location: SavedLocation) {
        locationManager?.updateLocation(
            latitude: location.latitude,
            longitude: location.longitude,
            cityName: location.name
        )
        locationManager?.searchRadius = 50 // Set to normal radius
        
        // Add to recent locations
        if !recentLocations.contains(where: { $0.id == location.id }) {
            recentLocations.insert(location, at: 0)
            if recentLocations.count > 10 {
                recentLocations.removeLast()
            }
            saveRecentLocations()
        }
    }
    
    private func saveRecentLocations() {
        if let data = try? JSONEncoder().encode(recentLocations) {
            UserDefaults.standard.set(data, forKey: recentLocationsKey)
        }
    }
}

class LocationSearchViewModel: NSObject, ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [MKLocalSearchCompletion] = []
    @Published var isSearching: Bool = false
    
    var locationManager: LocationManager?
    
    private var searchCompleter = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .query]
        
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] searchText in
                self?.performSearch(query: searchText)
            }
            .store(in: &cancellables)
    }
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        searchCompleter.queryFragment = query
    }
    
    func clearResults() {
        searchResults = []
        isSearching = false
    }
    
    func selectLocation(_ completion: MKLocalSearchCompletion, completionHandler: @escaping (Bool, CLLocationCoordinate2D?) -> Void) {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { [weak self] response, error in
            guard let self = self,
                  let response = response,
                  let item = response.mapItems.first,
                  let location = item.placemark.location else {
                completionHandler(false, nil)
                return
            }
            
            let cityName = self.formatCityName(from: item.placemark)
            
            DispatchQueue.main.async {
                self.locationManager?.updateLocation(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    cityName: cityName
                )
                completionHandler(true, location.coordinate)
            }
        }
    }
    
    private func formatCityName(from placemark: MKPlacemark) -> String {
        var components: [String] = []
        
        if let city = placemark.locality {
            components.append(city)
        }
        if let state = placemark.administrativeArea {
            components.append(state)
        }
        
        return components.isEmpty ? "Selected Location" : components.joined(separator: ", ")
    }
}

extension LocationSearchViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.searchResults = completer.results
            self.isSearching = false
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isSearching = false
        }
    }
}

// MARK: - Helper Struct for Map Annotations
struct IdentifiableCoordinate: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - LocationManager Extension (Add this property)
extension LocationManager {
    private static var radiusKey = "searchRadius"
    
    var searchRadius: Double {
        get {
            return UserDefaults.standard.double(forKey: LocationManager.radiusKey) != 0
                ? UserDefaults.standard.double(forKey: LocationManager.radiusKey)
                : 50.0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: LocationManager.radiusKey)
        }
    }
}

// MARK: - Updated Notification View
struct NotificationView: View {
    @Binding var hasUnreadNotifications: Bool
    
    var body: some View {
        VStack {
            Text("Notifications")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            Image(systemName: "bell.slash")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No new notifications")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding()
            
            Spacer()
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Mark notifications as read when view appears
            hasUnreadNotifications = false
        }
    }
}

private func formatDistance(_ distance: Double) -> String {
    return distance < 1000 ? String(format: "%.0f m", distance) : String(format: "%.1f km", distance / 1000)
}


private func isBusinessOpen(_ business: Business, _ workHours: WorkHours) -> Bool {
    let weekday = Calendar.current.component(.weekday, from: Date())
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm"
    let currentTime = timeFormatter.string(from: Date())
    
    let dayHours: DayHours
    switch weekday {
    case 1: dayHours = workHours.sunday
    case 2: dayHours = workHours.monday
    case 3: dayHours = workHours.tuesday
    case 4: dayHours = workHours.wednesday
    case 5: dayHours = workHours.thursday
    case 6: dayHours = workHours.friday
    case 7: dayHours = workHours.saturday
    default: return false
    }
    
    return dayHours.isOpen && currentTime >= dayHours.openTime && currentTime <= dayHours.closeTime
}


struct EnhancedBusinessCardView: View {
    let business: Business
    let distance: Double?
    let isFavorite: Bool
    let onTap: () -> Void
    let onCall: () -> Void
    let onDirections: () -> Void
    let onShare: () -> Void
    let onFavorite: () -> Void
    
    @State private var showActions = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 14) {
                    // Image
                    AsyncImage(url: URL(string: business.photoURLs.first ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Rectangle()
                                .fill(LinearGradient(
                                    colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                }
                        }
                    }
                    .frame(width: 110, height: 110)
                    .cornerRadius(16)
                    
                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(business.name)
                                .font(.headline)
                                .fontWeight(.bold)
                                .lineLimit(2)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: onFavorite) {
                                Image(systemName: isFavorite ? "heart.fill" : "heart")
                                    .foregroundColor(isFavorite ? .red : .gray)
                                    .font(.system(size: 20))
                            }
                        }
                        
                        // Rating
                        HStack(spacing: 4) {
                            if business.rating > 0 {
                                ForEach(0..<5) { index in
                                    Image(systemName: index < Int(business.rating) ? "star.fill" : "star")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                Text(String(format: "%.1f", business.rating))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("(\(business.reviewCount))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("No ratings yet")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Tags
                        HStack(spacing: 8) {
                            Text(business.category)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                            
                            if let workHours = business.workHours, isBusinessOpen(business, workHours) {
                                HStack(spacing: 3) {
                                    Circle().fill(Color.blue).frame(width: 5, height: 5)
                                    Text("Open").font(.caption).foregroundColor(.green)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                        
                        if let distance = distance {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(formatDistance(distance))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(14)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Quick Actions
            if showActions {
                Divider()
                HStack(spacing: 0) {
                    HomeQuickActionButton(icon: "phone.fill", title: "Call", color: .green, action: onCall)
                    Divider().frame(height: 30)
                    HomeQuickActionButton(icon: "location.fill", title: "Directions", color: .blue, action: onDirections)
                    Divider().frame(height: 30)
                    HomeQuickActionButton(icon: "square.and.arrow.up", title: "Share", color: .purple, action: onShare)
                }
                .padding(.vertical, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                showActions.toggle()
            }
        }
    }
    
    private func formatDistance(_ distance: Double) -> String {
        distance < 1000 ? String(format: "%.0f m", distance) : String(format: "%.1f km", distance / 1000)
    }
    
    private func isBusinessOpen(_ business: Business, _ workHours: WorkHours) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let currentTime = timeFormatter.string(from: Date())
        let dayHours: DayHours
        switch weekday {
        case 1: dayHours = workHours.sunday; case 2: dayHours = workHours.monday; case 3: dayHours = workHours.tuesday
        case 4: dayHours = workHours.wednesday; case 5: dayHours = workHours.thursday
        case 6: dayHours = workHours.friday; case 7: dayHours = workHours.saturday; default: return false
        }
        return dayHours.isOpen && currentTime >= dayHours.openTime && currentTime <= dayHours.closeTime
    }
}

struct HomeQuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 14))
                Text(title).font(.caption).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(color)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Compact cards for grid/compact views
struct CompactBusinessCard: View {
    let business: Business
    let distance: Double?
    let isFavorite: Bool
    let onTap: () -> Void
    let onFavorite: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: URL(string: business.photoURLs.first ?? "")) { phase in
                        switch phase {
                        case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                        default: Rectangle().fill(LinearGradient(colors: [.blue.opacity(0.2), .purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                    }
                    .frame(height: 140)
                    .clipped()
                    
                    Button(action: onFavorite) {
                        ZStack {
                            Circle().fill(.ultraThinMaterial).frame(width: 32, height: 32)
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 14))
                                .foregroundColor(isFavorite ? .red : .white)
                        }
                    }
                    .padding(8)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(business.name).font(.subheadline).fontWeight(.bold).lineLimit(2).foregroundColor(.primary)
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").foregroundColor(.orange).font(.caption2)
                        Text(String(format: "%.1f", business.rating)).font(.caption2).fontWeight(.medium)
                    }
                    if let distance = distance {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill").font(.caption2).foregroundColor(.blue)
                            Text(formatDistance(distance)).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }.padding(10)
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.06), radius: 8, y: 4))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDistance(_ distance: Double) -> String {
        distance < 1000 ? String(format: "%.0f m", distance) : String(format: "%.1f km", distance / 1000)
    }
}

struct CompactListCard: View {
    let business: Business
    let distance: Double?
    let isFavorite: Bool
    let onTap: () -> Void
    let onFavorite: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: business.photoURLs.first ?? "")) { phase in
                    switch phase {
                    case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                    default: Rectangle().fill(Color.blue.opacity(0.2))
                    }
                }
                .frame(width: 70, height: 70)
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(business.name).font(.subheadline).fontWeight(.bold).lineLimit(1)
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").foregroundColor(.orange).font(.caption2)
                        Text(String(format: "%.1f", business.rating)).font(.caption2)
                        if let distance = distance {
                            Text("•").foregroundColor(.secondary).font(.caption2)
                            Text(formatDistance(distance)).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    Text(business.category).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button(action: onFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? .red : .gray)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.04), radius: 4))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDistance(_ distance: Double) -> String {
        distance < 1000 ? String(format: "%.0f m", distance) : String(format: "%.1f km", distance / 1000)
    }
}

