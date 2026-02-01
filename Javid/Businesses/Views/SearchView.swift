import SwiftUI
import CoreLocation
import MapKit

struct SearchView: View {
    @ObservedObject var businessViewModel: BusinessViewModel
    @EnvironmentObject var favoriteViewModel: FavoriteViewModel
    @StateObject private var locationManager = LocationManager()
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Search State
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @FocusState private var isSearchFocused: Bool
    
    // MARK: - View Configuration
    @State private var viewMode: ViewMode = .card
    @State private var sortBy: SortOption = .relevance
    @State private var showFilterSheet = false
    @State private var showMapView = false
    
    // MARK: - Filters
    @State private var minRating: Double = 0
    @State private var maxDistance: Double = 50
    @State private var priceRange: Set<String> = []
    @State private var isOpenNowFilter: Bool = false
    
    // MARK: - UI State
    @State private var trendingSearches: [String] = ["Italian Restaurant", "Coffee Shop", "Hair Salon", "Gym Near Me", "Pet Store", "Dentist"]
    @State private var recentSearches: [String] = []
    @State private var showSuggestions = false
    @State private var selectedBusiness: Business?
    @State private var isPerformingSearch = false
    
    // MARK: - Recently Viewed
    @State private var recentlyViewed: [Business] = []
    @AppStorage("recentlyViewedIds") private var recentlyViewedIds: String = ""
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
    
    enum SortOption: String, CaseIterable {
        case relevance = "Relevance"
        case distance = "Distance"
        case rating = "Rating"
        case reviewCount = "Most Reviewed"
        case alphabetical = "A-Z"
        
        var icon: String {
            switch self {
            case .relevance: return "sparkles"
            case .distance: return "location.circle.fill"
            case .rating: return "star.circle.fill"
            case .reviewCount: return "text.bubble.fill"
            case .alphabetical: return "textformat.abc"
            }
        }
    }
    
    let categories = ["All", "Restaurant", "Cafe", "Store", "Services", "Doctor", "Lawyer", "Salon", "Gym", "Hotel", "Bar", "Spa"]
    
    // MARK: - Computed Properties
    var filteredBusinesses: [Business] {
        var businesses = businessViewModel.businesses
        
        // Search filter
        if !searchText.isEmpty {
            businesses = businesses.filter { business in
                business.name.localizedCaseInsensitiveContains(searchText) ||
                business.city.localizedCaseInsensitiveContains(searchText) ||
                business.description.localizedCaseInsensitiveContains(searchText) ||
                business.address.localizedCaseInsensitiveContains(searchText) ||
                business.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Category filter
        if selectedCategory != "All" {
            businesses = businesses.filter { $0.category == selectedCategory }
        }
        
        // Advanced filters
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
        
        // Sorting
        switch sortBy {
        case .relevance:
            // Keep original order for relevance
            break
        case .distance:
            if let userLocation = locationManager.location {
                businesses.sort { b1, b2 in
                    let loc1 = CLLocation(latitude: b1.latitude, longitude: b1.longitude)
                    let loc2 = CLLocation(latitude: b2.latitude, longitude: b2.longitude)
                    return userLocation.distance(from: loc1) < userLocation.distance(from: loc2)
                }
            }
        case .rating:
            businesses.sort { $0.rating > $1.rating }
        case .reviewCount:
            businesses.sort { $0.reviewCount > $1.reviewCount }
        case .alphabetical:
            businesses.sort { $0.name < $1.name }
        }
        
        return businesses
    }
    
    var searchSuggestions: [String] {
        guard !searchText.isEmpty else { return [] }
        
        let allSuggestions = businessViewModel.businesses.map { $0.name } +
                            businessViewModel.businesses.map { $0.category } +
                            businessViewModel.businesses.map { $0.city }
        
        return Array(Set(allSuggestions))
            .filter { $0.localizedCaseInsensitiveContains(searchText) }
            .prefix(5)
            .map { String($0) }
    }
    
    var hasActiveFilters: Bool {
        minRating > 0 || maxDistance < 50 || !priceRange.isEmpty || isOpenNowFilter
    }
    
    var activeFiltersCount: Int {
        var count = 0
        if minRating > 0 { count += 1 }
        if maxDistance < 50 { count += 1 }
        if !priceRange.isEmpty { count += 1 }
        if isOpenNowFilter { count += 1 }
        return count
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                backgroundView
                
                VStack(spacing: 0) {
                    // Premium Header
                    headerSection
                    
                    // Search Bar
                    searchBarSection
                    
                    // Content
                    contentView
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedBusiness) { business in
                BusinessDetailView(business: business)
                    .onDisappear {
                        if !searchText.isEmpty {
                            addToSearchHistory(searchText)
                        }
                        addToRecentlyViewed(business)
                    }
            }
            .sheet(isPresented: $showFilterSheet) {
                AdvancedFilterSheet(
                    minRating: $minRating,
                    maxDistance: $maxDistance,
                    priceRange: $priceRange,
                    isOpenNow: $isOpenNowFilter,
                    onApply: {
                        showFilterSheet = false
                        hapticFeedback(.medium)
                    }
                )
            }
            .sheet(isPresented: $showMapView) {
                AdvancedMapView(
                    businesses: filteredBusinesses,
                    userLocation: locationManager.location
                )
            }
            .onAppear {
                setupView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Background View
    @ViewBuilder
    private var backgroundView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            AnimatedBackground()
                .ignoresSafeArea()
                .opacity(0.3)
        }
    }
    
    // MARK: - Header Section
    @ViewBuilder
    private var headerSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Search")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                if !searchText.isEmpty {
                    Text("\(filteredBusinesses.count) result\(filteredBusinesses.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Search Bar Section
    @ViewBuilder
    private var searchBarSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Search Input
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    TextField("Search businesses, categories...", text: $searchText)
                        .font(.system(size: 16))
                        .focused($isSearchFocused)
                        .onChange(of: searchText) { newValue in
                            withAnimation {
                                showSuggestions = !newValue.isEmpty
                            }
                        }
                        .submitLabel(.search)
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            withAnimation {
                                searchText = ""
                                showSuggestions = false
                            }
                            hapticFeedback(.soft)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            
            // Categories Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories, id: \.self) { category in
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
            
            // Filter & Sort Bar (shown when searching)
            if !searchText.isEmpty {
                HStack(spacing: 12) {
                    // Filter Button
                    Button(action: {
                        showFilterSheet.toggle()
                        hapticFeedback(.medium)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Filters")
                                .font(.system(size: 15, weight: .medium))
                            if hasActiveFilters {
                                ZStack {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 18, height: 18)
                                    Text("\(activeFiltersCount)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                    
                    // Sort Menu
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button(action: {
                                withAnimation {
                                    sortBy = option
                                }
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
                    
                    // View Mode Toggle
                    Button(action: cycleViewMode) {
                        Image(systemName: viewMode.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.blue.opacity(0.1)))
                    }
                }
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.bottom, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        if searchText.isEmpty && !isSearchFocused {
            discoverContent
        } else if searchText.isEmpty && isSearchFocused {
            searchSuggestionsContent
        } else if showSuggestions && !searchSuggestions.isEmpty && isSearchFocused {
            suggestionsListView
        } else {
            searchResultsContent
        }
    }
    
    // MARK: - Discover Content (Empty State)
    @ViewBuilder
    private var discoverContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                // Hero
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(spacing: 8) {
                        Text("Discover Amazing Places")
                            .font(.system(size: 24, weight: .bold))
                            .multilineTextAlignment(.center)
                        
                        Text("Search for restaurants, stores, services\nand more near you")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }
                .padding(.top, 20)
                
                // Trending Searches
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Text("Trending Searches")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(trendingSearches, id: \.self) { trend in
                                TrendingSearchCard(title: trend) {
                                    searchText = trend
                                    performSearch()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // Recent Searches
                if !recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.blue)
                            Text("Recent Searches")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation {
                                    clearSearchHistory()
                                }
                            }) {
                                Text("Clear")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        VStack(spacing: 10) {
                            ForEach(recentSearches.prefix(5), id: \.self) { search in
                                RecentSearchRow(search: search) {
                                    searchText = search
                                    performSearch()
                                } onDelete: {
                                    removeFromHistory(search)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // Recently Viewed
                if !recentlyViewed.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "eye.fill")
                                .foregroundColor(.purple)
                            Text("Recently Viewed")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation {
                                    clearRecentlyViewed()
                                }
                            }) {
                                Text("Clear")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(recentlyViewed.prefix(5)) { business in
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
                                    .frame(width: 280)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Search Suggestions Content
    @ViewBuilder
    private var searchSuggestionsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Popular Categories
                VStack(alignment: .leading, spacing: 16) {
                    Text("Popular Categories")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.horizontal, 20)
                    
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        ForEach(categories.filter { $0 != "All" }.prefix(6), id: \.self) { category in
                            CategoryActionCard(
                                title: category,
                                icon: iconForCategory(category),
                                count: businessViewModel.businesses.filter { $0.category == category }.count
                            ) {
                                withAnimation {
                                    selectedCategory = category
                                    isSearchFocused = false
                                }
                                hapticFeedback()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Search Tips
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("Search Tips")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        SearchTipRow(icon: "location.fill", text: "Try searching by city name")
                        SearchTipRow(icon: "tag.fill", text: "Use specific categories")
                        SearchTipRow(icon: "star.fill", text: "Look for highly rated places")
                        SearchTipRow(icon: "magnifyingglass", text: "Search by business name")
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 20)
        }
    }
    
    // MARK: - Suggestions List
    @ViewBuilder
    private var suggestionsListView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(searchSuggestions, id: \.self) { suggestion in
                    Button(action: {
                        searchText = suggestion
                        showSuggestions = false
                        performSearch()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                            
                            Text(suggestion)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.left")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if suggestion != searchSuggestions.last {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Search Results Content
    @ViewBuilder
    private var searchResultsContent: some View {
        if filteredBusinesses.isEmpty {
            noResultsView
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    switch viewMode {
                    case .card:
                        cardLayoutView
                    case .list:
                        listLayoutView
                    case .grid:
                        gridLayoutView
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Layout Views
    @ViewBuilder
    private var cardLayoutView: some View {
        LazyVStack(spacing: 20) {
            ForEach(Array(filteredBusinesses.enumerated()), id: \.element.id) { index, business in
                Button(action: {
                    selectedBusiness = business
                    hapticFeedback(.soft)
                }) {
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
                    value: filteredBusinesses.count
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var listLayoutView: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredBusinesses) { business in
                Button(action: {
                    selectedBusiness = business
                    hapticFeedback(.soft)
                }) {
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
            ForEach(filteredBusinesses) { business in
                Button(action: {
                    selectedBusiness = business
                    hapticFeedback(.soft)
                }) {
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
    }
    
    // MARK: - No Results View
    @ViewBuilder
    private var noResultsView: some View {
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
                
                Image(systemName: "doc.text.magnifyingglass")
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
                
                Text("Try different keywords or\nadjust your filters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            HStack(spacing: 12) {
                if hasActiveFilters {
                    Button(action: resetFilters) {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Clear Filters")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                Button(action: {
                    withAnimation {
                        searchText = ""
                        selectedCategory = "All"
                        resetFilters()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("New Search")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.3), radius: 12, y: 6)
                }
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - Extension - Helper Functions
extension SearchView {
    
    private func setupView() {
        loadSearchHistory()
        loadRecentlyViewed()
        locationManager.requestPermission()
        locationManager.startUpdating()
    }
    
    private func performSearch() {
        withAnimation {
            isSearchFocused = false
            showSuggestions = false
        }
        
        if !searchText.isEmpty {
            addToSearchHistory(searchText)
        }
        
        hapticFeedback(.medium)
    }
    
    private func cycleViewMode() {
        withAnimation(.spring(response: 0.3)) {
            switch viewMode {
            case .card: viewMode = .list
            case .list: viewMode = .grid
            case .grid: viewMode = .card
            }
            hapticFeedback()
        }
    }
    
    private func resetFilters() {
        withAnimation(.spring(response: 0.3)) {
            minRating = 0
            maxDistance = 50
            priceRange = []
            isOpenNowFilter = false
            hapticFeedback(.medium)
        }
    }
    
    private func loadSearchHistory() {
        let searches = searchHistoryString.split(separator: ",").map(String.init)
        recentSearches = Array(searches.prefix(10))
    }
    
    private func addToSearchHistory(_ search: String) {
        guard !search.isEmpty, search.count > 1 else { return }
        
        var searches = recentSearches
        
        // Remove if already exists
        searches.removeAll { $0.lowercased() == search.lowercased() }
        
        // Add to beginning
        searches.insert(search, at: 0)
        
        // Keep only last 10
        searches = Array(searches.prefix(10))
        
        recentSearches = searches
        searchHistoryString = searches.joined(separator: ",")
    }
    
    private func removeFromHistory(_ search: String) {
        withAnimation {
            recentSearches.removeAll { $0 == search }
            searchHistoryString = recentSearches.joined(separator: ",")
            hapticFeedback(.soft)
        }
    }
    
    private func clearSearchHistory() {
        recentSearches = []
        searchHistoryString = ""
        hapticFeedback(.soft)
    }
    
    private func loadRecentlyViewed() {
        let ids = recentlyViewedIds.split(separator: ",").map(String.init)
        recentlyViewed = ids.compactMap { id in
            businessViewModel.businesses.first { $0.id == id }
        }
    }
    
    private func addToRecentlyViewed(_ business: Business) {
        guard let businessId = business.id else { return }
        
        var ids = recentlyViewedIds.split(separator: ",").map(String.init)
        ids.removeAll { $0 == businessId }
        ids.insert(businessId, at: 0)
        ids = Array(ids.prefix(10))
        
        recentlyViewedIds = ids.joined(separator: ",")
        loadRecentlyViewed()
    }
    
    private func clearRecentlyViewed() {
        recentlyViewed = []
        recentlyViewedIds = ""
        hapticFeedback(.soft)
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
            "Services": "wrench.and.screwdriver",
            "Lawyer": "briefcase.fill"
        ]
        return icons[category] ?? "star.fill"
    }
    
    private func toggleFavorite(_ business: Business) {
        guard let businessId = business.id else { return }
        hapticFeedback(.medium)
        
        favoriteViewModel.toggleFavorite(businessId: businessId) { success, message in
            if !success {
                print("Error toggling favorite: \(message)")
            }
        }
    }
    
    private func callBusiness(_ business: Business) {
        guard !business.phone.isEmpty else { return }
        
        let phoneNumber = business.phone.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        
        if let url = URL(string: "tel://\(phoneNumber)") {
            UIApplication.shared.open(url)
        }
        hapticFeedback(.medium)
    }
    
    private func openDirections(to business: Business) {
        let coordinate = CLLocationCoordinate2D(
            latitude: business.latitude,
            longitude: business.longitude
        )
        
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
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
        
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
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

struct TrendingSearchCard: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .font(.system(size: 16))
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct RecentSearchRow: View {
    let search: String
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            Button(action: onTap) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    
                    Text(search)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
        )
    }
}

struct CategoryActionCard: View {
    let title: String
    let icon: String
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("\(count) places")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct SearchTipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}
