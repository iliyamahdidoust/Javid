import SwiftUI
import CoreLocation
import MapKit

struct HomeView: View {
    @ObservedObject var businessViewModel: BusinessViewModel
    @EnvironmentObject var favoriteViewModel: FavoriteViewModel
    @StateObject private var locationManager = LocationManager()
    
    // UI State
    @State private var selectedCategory: String?
    @State private var viewMode: ViewMode = .list
    @State private var activeFilter: QuickFilter = .all
    @State private var sortBy: SortOption = .distance
    @State private var showingMapView = false
    @State private var scrollOffset: CGFloat = 0
    @State private var headerOpacity: Double = 0
    @State private var showSearchSheet = false
    @State private var showFilterSheet = false
    @State private var selectedBusiness: Business?
    @State private var showBusinessDetail = false
    
    // Advanced filters
    @State private var minRating: Double = 0
    @State private var maxDistance: Double = 50
    @State private var priceRange: Set<String> = []
    @State private var isOpenNow: Bool = false
    
    enum ViewMode { case list, grid, compact }
    enum QuickFilter { case all, openNow, topRated, nearby, trending }
    enum SortOption { case distance, rating, reviewCount, newest }
    
    var body: some View {
        let _ = print("DEBUG: Business count = \(businessViewModel.businesses.count)")
        let _ = print("DEBUG: Filtered count = \(filteredAndSortedBusinesses.count)")

        NavigationView {
            ZStack {
                // Animated background with gradient
                AnimatedBackground()
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        // Hero Section with Parallax
                        heroSection
                            .offset(y: scrollOffset * 0.5)
                        
                        VStack(spacing: 24) {
                            // Stats Overview
                            statsOverview
                            
                            // Quick Actions
                            quickActionsSection
                            
                            // Quick Filters with Haptic
                            quickFiltersSection
                            
                            // Featured/Trending Carousel
                            if !featuredBusinesses.isEmpty {
                                featuredCarousel
                            }
                            
                            // Categories with Icons
                            categorySection
                            
                            // Sort & View Mode
                            sortAndViewSection
                            
                            // Main Business List
                            businessListSection
                            
                        }
                        .padding(.top, 20)
                    }
                }
                .coordinateSpace(name: "scroll")
                .overlay(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: HomeScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).minY
                        )
                    }
                )
                .onPreferenceChange(HomeScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                    withAnimation(.easeInOut(duration: 0.2)) {
                        headerOpacity = min(max(-value / 100, 0), 1)
                    }
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        floatingActionButton
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                    }
                }
                
                // Loading overlay
                if businessViewModel.isLoading && businessViewModel.businesses.isEmpty {
                    modernLoadingView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Discover")
                            .font(.headline)
                            .fontWeight(.bold)
                        if let location = locationManager.location {
                            Text("Toronto, ON")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .opacity(headerOpacity)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { toggleViewMode() }) {
                            Image(systemName: viewModeIcon)
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                        }
                        
                        NavigationLink(destination: NotificationView()) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell")
                                    .font(.system(size: 18))
                                    .foregroundColor(.primary)
                                
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingMapView) {
                AdvancedMapView(businesses: filteredAndSortedBusinesses, userLocation: locationManager.location)
            }
            .sheet(isPresented: $showFilterSheet) {
                AdvancedFilterSheet(
                    minRating: $minRating,
                    maxDistance: $maxDistance,
                    priceRange: $priceRange,
                    isOpenNow: $isOpenNow,
                    onApply: { applyFilters() }
                )
            }
            .sheet(item: $selectedBusiness) { business in
                BusinessDetailView(business: business)
            }
        }
        .onAppear {
            if businessViewModel.businesses.isEmpty {
                businessViewModel.fetchBusinesses()
            }
            locationManager.requestPermission()
            locationManager.startUpdating()
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Explore")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                        
                        Text("Toronto, Ontario")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Profile Avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text("IL")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Stats Overview
    private var statsOverview: some View {
        HStack(spacing: 12) {
            HomeStatCard(
                icon: "building.2.fill",
                value: "\(businessViewModel.businesses.count)",
                label: "Places",
                color: .blue
            )
            
            HomeStatCard(
                icon: "star.fill",
                value: String(format: "%.1f", averageRating),
                label: "Avg Rating",
                color: .orange
            )
            
            HomeStatCard(
                icon: "heart.fill",
                value: "\(favoriteViewModel.favorites.count)",
                label: "Favorites",
                color: .red
            )
            
            HomeStatCard(
                icon: "clock.fill",
                value: "\(openNowBusinesses.count)",
                label: "Open Now",
                color: .green
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                QuickActionCard(
                    icon: "sparkles",
                    title: "AI Picks",
                    subtitle: "For You",
                    gradient: [.purple, .pink],
                    action: { activeFilter = .trending }
                )
                
                QuickActionCard(
                    icon: "crown.fill",
                    title: "Premium",
                    subtitle: "Top Rated",
                    gradient: [.orange, .red],
                    action: { activeFilter = .topRated }
                )
                
                QuickActionCard(
                    icon: "location.fill",
                    title: "Nearby",
                    subtitle: "Close to you",
                    gradient: [.blue, .cyan],
                    action: { activeFilter = .nearby }
                )
                
                QuickActionCard(
                    icon: "clock.fill",
                    title: "Open Now",
                    subtitle: "Visit today",
                    gradient: [.green, .mint],
                    action: { activeFilter = .openNow }
                )
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Quick Filters
    private var quickFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                HomeFilterChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: activeFilter == .all,
                    count: businessViewModel.businesses.count
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        activeFilter = .all
                        hapticFeedback()
                    }
                }
                
                HomeFilterChip(
                    title: "Trending",
                    icon: "flame.fill",
                    isSelected: activeFilter == .trending,
                    count: trendingBusinesses.count
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        activeFilter = .trending
                        hapticFeedback()
                    }
                }
                
                HomeFilterChip(
                    title: "Open Now",
                    icon: "clock.fill",
                    isSelected: activeFilter == .openNow,
                    count: openNowBusinesses.count
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        activeFilter = .openNow
                        hapticFeedback()
                    }
                }
                
                HomeFilterChip(
                    title: "Top Rated",
                    icon: "star.fill",
                    isSelected: activeFilter == .topRated,
                    count: topRatedBusinesses.count
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        activeFilter = .topRated
                        hapticFeedback()
                    }
                }
                
                HomeFilterChip(
                    title: "Nearby",
                    icon: "location.fill",
                    isSelected: activeFilter == .nearby,
                    count: nearbyBusinesses.count
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        activeFilter = .nearby
                        hapticFeedback()
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Featured Carousel
    private var featuredCarousel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 20))
                    Text("Trending Now")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                Spacer()
                Button(action: { activeFilter = .trending }) {
                    Text("View All")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(featuredBusinesses.prefix(8)) { business in
                        PremiumBusinessCard(
                            business: business,
                            distance: distance(to: business),
                            isFavorite: favoriteViewModel.isFavorite(businessId: business.id ?? "")
                        ) {
                            selectedBusiness = business
                        } onFavorite: {
                            toggleFavorite(business)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Category Section
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)
            
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
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Sort & View Mode
    private var sortAndViewSection: some View {
        HStack(spacing: 12) {
            Menu {
                Button(action: { sortBy = .distance }) {
                    Label("Distance", systemImage: sortBy == .distance ? "checkmark" : "")
                }
                Button(action: { sortBy = .rating }) {
                    Label("Rating", systemImage: sortBy == .rating ? "checkmark" : "")
                }
                Button(action: { sortBy = .reviewCount }) {
                    Label("Most Reviewed", systemImage: sortBy == .reviewCount ? "checkmark" : "")
                }
                Button(action: { sortBy = .newest }) {
                    Label("Newest", systemImage: sortBy == .newest ? "checkmark" : "")
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14))
                    Text(sortByText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(20)
            }
            
            Spacer()
            
            Text("\(filteredAndSortedBusinesses.count) results")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Business List Section
    private var businessListSection: some View {
        let _ = print("DEBUG: Rendering business list")
        return Group {
            if filteredAndSortedBusinesses.isEmpty {
                modernEmptyStateView
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(Array(filteredAndSortedBusinesses.enumerated()), id: \.element.id) { index, business in
                        businessCardForMode(business: business, index: index)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private func businessCardForMode(business: Business, index: Int) -> some View {
        switch viewMode {
        case .list:
            EnhancedBusinessCardView(
                business: business,
                distance: distance(to: business),
                isFavorite: favoriteViewModel.isFavorite(businessId: business.id ?? ""),
                onTap: { selectedBusiness = business },
                onCall: { callBusiness(business) },
                onDirections: { openDirections(to: business) },
                onShare: { shareBusiness(business) },
                onFavorite: { toggleFavorite(business) }
            )
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .opacity
            ))
            .animation(
                .spring(response: 0.4, dampingFraction: 0.8)
                .delay(Double(index) * 0.05),
                value: filteredAndSortedBusinesses.count
            )
            
        case .grid:
            // Grid view will be in Part 2
            CompactBusinessCard(
                business: business,
                distance: distance(to: business),
                isFavorite: favoriteViewModel.isFavorite(businessId: business.id ?? ""),
                onTap: { selectedBusiness = business },
                onFavorite: { toggleFavorite(business) }
            )
            
        case .compact:
            CompactListCard(
                business: business,
                distance: distance(to: business),
                isFavorite: favoriteViewModel.isFavorite(businessId: business.id ?? ""),
                onTap: { selectedBusiness = business },
                onFavorite: { toggleFavorite(business) }
            )
        }
    }
    
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        Button(action: { showingMapView.toggle() }) {
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
    }
    
    // MARK: - Load More Button
    private var loadMoreButton: some View {
        Button(action: { businessViewModel.loadMoreBusinesses() }) {
            HStack {
                if businessViewModel.isLoadingMore {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Load More")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.down.circle.fill")
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .padding(.horizontal)
        }
        .disabled(businessViewModel.isLoadingMore)
    }
    
    // MARK: - Modern Loading View
    private var modernLoadingView: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                LottieLoadingView()
                
                VStack(spacing: 8) {
                    Text("Discovering Places")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Finding the best spots for you...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
    
    // MARK: - Modern Empty State
    private var modernEmptyStateView: some View {
        VStack(spacing: 24) {
            LottieEmptyStateView()
            
            VStack(spacing: 12) {
                Text("No Results Found")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Try adjusting your filters or explore different categories")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: { resetFilters() }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset Filters")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
            }
        }
        .padding(.top, 60)
        .padding(.bottom, 40)
    }
}
// MARK: - HomeView Extension - Computed Properties & Helper Functions

extension HomeView {
    // MARK: - Computed Properties
    
    private var viewModeIcon: String {
        switch viewMode {
        case .list: return "square.grid.2x2"
        case .grid: return "list.bullet"
        case .compact: return "square.grid.3x2"
        }
    }
    
    private var sortByText: String {
        switch sortBy {
        case .distance: return "Distance"
        case .rating: return "Rating"
        case .reviewCount: return "Reviews"
        case .newest: return "Newest"
        }
    }
    
    private var averageRating: Double {
        guard !businessViewModel.businesses.isEmpty else { return 0 }
        let total = businessViewModel.businesses.reduce(0.0) { $0 + $1.rating }
        return total / Double(businessViewModel.businesses.count)
    }
    
    private var availableCategories: [String] {
        Array(Set(businessViewModel.businesses.map { $0.category })).sorted()
    }
    
    private var filteredAndSortedBusinesses: [Business] {
        var businesses = businessViewModel.businesses
        
        // Category filter
        if let category = selectedCategory {
            businesses = businesses.filter { $0.category == category }
        }
        
        // Advanced filters
        if minRating > 0 {
            businesses = businesses.filter { $0.rating >= minRating }
        }
        
        if isOpenNow {
            businesses = businesses.filter { isBusinessOpen($0) }
        }
        
        if let userLocation = locationManager.location {
            businesses = businesses.filter {
                let dist = CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                    .distance(from: userLocation) / 1000
                return dist <= maxDistance
            }
        }
        
        // Quick filter
        switch activeFilter {
        case .openNow:
            businesses = businesses.filter { isBusinessOpen($0) }
        case .topRated:
            businesses = businesses.filter { $0.rating >= 4.5 }
        case .nearby:
            if let userLocation = locationManager.location {
                businesses = businesses.filter {
                    CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                        .distance(from: userLocation) <= 5000
                }
            }
        case .trending:
            businesses = trendingBusinesses
        default:
            break
        }
        
        // Sorting
        switch sortBy {
        case .distance:
            if let userLocation = locationManager.location {
                businesses.sort {
                    userLocation.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude)) <
                    userLocation.distance(from: CLLocation(latitude: $1.latitude, longitude: $1.longitude))
                }
            }
        case .rating:
            businesses.sort { $0.rating > $1.rating }
        case .reviewCount:
            businesses.sort { $0.reviewCount > $1.reviewCount }
        case .newest:
            businesses.reverse()
        }
        
        return businesses
    }
    
    private var featuredBusinesses: [Business] {
        businessViewModel.businesses
            .filter { $0.rating >= 4.5 && $0.reviewCount >= 10 }
            .sorted { $0.reviewCount > $1.reviewCount }
    }
    
    private var trendingBusinesses: [Business] {
        businessViewModel.businesses
            .filter { $0.rating >= 4.0 && $0.reviewCount >= 5 }
            .sorted { $0.reviewCount > $1.reviewCount }
    }
    
    private var openNowBusinesses: [Business] {
        businessViewModel.businesses.filter { isBusinessOpen($0) }
    }
    
    private var topRatedBusinesses: [Business] {
        businessViewModel.businesses.filter { $0.rating >= 4.5 }
    }
    
    private var nearbyBusinesses: [Business] {
        guard let userLocation = locationManager.location else { return [] }
        return businessViewModel.businesses.filter {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                .distance(from: userLocation) <= 5000
        }
    }
    
    // MARK: - Helper Functions
    
    private func distance(to business: Business) -> Double? {
        guard let userLocation = locationManager.location else { return nil }
        return userLocation.distance(from: CLLocation(latitude: business.latitude, longitude: business.longitude))
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
            "Gym": "figure.run",
            "Salon": "scissors",
            "Hospital": "cross.case.fill",
            "Hotel": "bed.double.fill",
            "Bar": "wineglass.fill",
            "Spa": "sparkles",
            "Cinema": "film.fill",
            "Park": "leaf.fill",
            "Museum": "building.columns.fill"
        ]
        return icons[category] ?? "star.fill"
    }
    
    private func toggleViewMode() {
        withAnimation(.spring(response: 0.3)) {
            switch viewMode {
            case .list: viewMode = .grid
            case .grid: viewMode = .compact
            case .compact: viewMode = .list
            }
            hapticFeedback()
        }
    }
    
    private func resetFilters() {
        withAnimation(.spring(response: 0.3)) {
            selectedCategory = nil
            activeFilter = .all
            sortBy = .distance
            minRating = 0
            maxDistance = 50
            isOpenNow = false
            priceRange = []
        }
    }
    
    private func applyFilters() {
        // Filters are applied through binding
        showFilterSheet = false
    }
    
    private func callBusiness(_ business: Business) {
        if let url = URL(string: "tel://\(business.phone.replacingOccurrences(of: " ", with: ""))") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openDirections(to business: Business) {
        let mapItem = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: business.latitude, longitude: business.longitude)
        ))
        mapItem.name = business.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    private func shareBusiness(_ business: Business) {
        let text = "Check out \(business.name)! Rated \(String(format: "%.1f", business.rating))⭐️\n\(business.description)"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    private func toggleFavorite(_ business: Business) {
        guard let businessId = business.id else { return }
        
        hapticFeedback(.medium)
        
        favoriteViewModel.toggleFavorite(businessId: businessId) { success, message in
            if !success {
                // Show error toast
                print("Error: \(message)")
            }
        }
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
                        ForEach(["$", "$", "$$", "$$"], id: \.self) { price in
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

// MARK: - Notification View (Placeholder)
struct NotificationView: View {
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
                                    Circle().fill(Color.green).frame(width: 5, height: 5)
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
