import SwiftUI
import MapKit
import FirebaseAuth

struct BusinessDetailView: View {
    let business: Business
    
    @StateObject private var reviewViewModel = ReviewViewModel()
    @EnvironmentObject var businessViewModel: BusinessViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var favoriteViewModel: FavoriteViewModel
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // UI State
    @State private var scrollOffset: CGFloat = 0
    @State private var headerOpacity: Double = 0
    @State private var showingPhotoGallery = false
    @State private var selectedPhotoIndex = 0
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingWorkHoursEditor = false
    @State private var showingAddReview = false
    @State private var showingAllReviews = false
    @State private var showingReportSheet = false
    @State private var showingBookingSheet = false
    @State private var showingAmenitiesEditor = false  // TODO: Uncomment when amenities feature is ready
    @State private var showingSocialMediaEditor = false  // TODO: Uncomment when social media feature is ready
    @State private var selectedTab: DetailTab = .overview
    @State private var reviewFilter: ReviewFilter = .all
    @State private var region: MKCoordinateRegion
    @State private var isRefreshing = false
    
    // MARK: - Claim System States
    @State private var showingClaimSheet = false
    @State private var showingClaimStatusSheet = false
    
    // Analytics (Only visible to owner)
    @State private var viewCount: Int = 0
    @State private var saveCount: Int = 0
    
    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case reviews = "Reviews"
        case photos = "Photos"
        case about = "About"
    }
    
    enum ReviewFilter: String, CaseIterable {
        case all = "All"
        case recent = "Recent"
        case highRated = "High Rated"
        case lowRated = "Low Rated"
        case withPhotos = "With Photos"
    }
    
    var isOwner: Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return business.ownerId == currentUserId
    }
    
    init(business: Business) {
        self.business = business
        _region = State(initialValue: MKCoordinateRegion(
            center: business.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero Image Section
                    heroImageSection
                        .offset(y: scrollOffset > 0 ? -scrollOffset * 0.5 : 0)
                    
                    // Main Content
                    VStack(spacing: 0) {
                        // Quick Info Bar
                        quickInfoBar
                            .padding(.top, 16)
                        
                        Divider()
                            .padding(.vertical, 12)
                        
                        // Tab Selector
                        tabSelector
                            .padding(.bottom, 12)
                        
                        Divider()
                        
                        // Tab Content
                        Group {
                            switch selectedTab {
                            case .overview:
                                overviewContent
                            case .reviews:
                                reviewsContent
                            case .photos:
                                photosContent
                            case .about:
                                aboutContent
                            }
                        }
                        .animation(.spring(response: 0.3), value: selectedTab)
                    }
                }
            }
            .coordinateSpace(name: "scroll")
            .overlay(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: DetailScrollOffsetPreferenceKey.self,
                        value: geometry.frame(in: .named("scroll")).minY
                    )
                }
            )
            .onPreferenceChange(DetailScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
                withAnimation(.easeInOut(duration: 0.2)) {
                    headerOpacity = min(max(-value / 100, 0), 1)
                }
            }
            .refreshable {
                await refreshData()
            }
            
            // Floating Header
            floatingHeader
            
            // Floating Action Buttons
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    floatingActionButtons
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingPhotoGallery) {
            PhotoGalleryView(photos: business.photoURLs, selectedIndex: $selectedPhotoIndex)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditBusinessView(business: business, businessViewModel: businessViewModel)
        }
        .sheet(isPresented: $showingAddReview) {
            AddReviewView(business: business, reviewViewModel: reviewViewModel)
        }
        .sheet(isPresented: $showingAllReviews) {
            AllReviewsView(business: business, reviews: filteredReviews)
        }
        .sheet(isPresented: $showingReportSheet) {
            ReportBusinessView(business: business)
        }
        // TODO: Uncomment when booking feature is implemented
         .sheet(isPresented: $showingBookingSheet) {
             if isOwner {
                 BookingSettingsView(business: business, businessViewModel: businessViewModel)
             } else if business.bookingEnabled == true {
                 BookingView(business: business)
             }
         }
        .sheet(isPresented: $showingWorkHoursEditor) {
            WorkHoursEditorView(business: business, businessViewModel: businessViewModel)
        }
        // TODO: Uncomment when amenities feature is implemented
         .sheet(isPresented: $showingAmenitiesEditor) {
             AmenitiesEditorView(business: business, businessViewModel: businessViewModel)
         }
        // TODO: Uncomment when social media feature is implemented
         .sheet(isPresented: $showingSocialMediaEditor) {
             SocialMediaEditorView(business: business, businessViewModel: businessViewModel)
         }
        // MARK: - 🆕 CLAIM SYSTEM SHEETS
        .sheet(isPresented: $showingClaimSheet) {
            ClaimBusinessView(authViewModel: authViewModel, business: business)
        }
        .sheet(isPresented: $showingClaimStatusSheet) {
            ClaimStatusView()
        }
        .alert("Delete Business", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteBusiness() }
        } message: {
            Text("Are you sure you want to delete '\(business.name)'? This action cannot be undone.")
        }
        .alert("Message", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {
                if alertMessage.contains("deleted successfully") { dismiss() }
            }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            reviewViewModel.fetchReviews(for: business.id ?? "")
            if isOwner {
                trackView()
            }
        }
    }
    
    // MARK: - Hero Image Section
    private var heroImageSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Image Carousel
            TabView(selection: $selectedPhotoIndex) {
                ForEach(Array(business.photoURLs.enumerated()), id: \.offset) { index, url in
                    AsyncImage(url: URL(string: url)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure(_):
                            placeholderImage
                        case .empty:
                            placeholderImage
                        @unknown default:
                            placeholderImage
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 350)
            .clipped()
            
            // Gradient Overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 350)
            
            // Business Info Overlay
            VStack(alignment: .leading, spacing: 8) {
                // Category Badge
                HStack(spacing: 8) {
                    Text(business.category)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.9))
                        .cornerRadius(20)
                    
                    if isBusinessOpen {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Open")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                    }
                }
                
                // Business Name
                Text(business.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4)
                
                // Location & Rating
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(business.city), \(business.country)")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("\(String(format: "%.1f", calculateAverageRating())) (\(reviewViewModel.reviews.count) reviews)")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(height: 350)
    }
    // MARK: - Floating Header
    private var floatingHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .shadow(color: .black.opacity(0.1), radius: 8)
            }
            
            Spacer()
            
            if headerOpacity > 0.5 {
                Text(business.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .opacity(headerOpacity)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { shareBusinessAction() }) {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .shadow(color: .black.opacity(0.1), radius: 8)
                }
                
                if isOwner {
                    Menu {
                        Button(action: { showingEditSheet = true }) {
                            Label("Edit Business", systemImage: "pencil")
                        }
                        Button(action: { showingWorkHoursEditor = true }) {
                            Label("Edit Hours", systemImage: "clock")
                        }
                        // TODO: Uncomment when booking feature is implemented
                         Button(action: { showingBookingSheet = true }) {
                             Label("Booking Settings", systemImage: "calendar.badge.clock")
                         }
                        // TODO: Uncomment when amenities feature is implemented
                         Button(action: { showingAmenitiesEditor = true }) {
                             Label("Edit Amenities", systemImage: "star.circle")
                         }
                        // TODO: Uncomment when social media feature is implemented
                         Button(action: { showingSocialMediaEditor = true }) {
                             Label("Social Media", systemImage: "link")
                         }
                        Divider()
                        Button(role: .destructive, action: { showingDeleteAlert = true }) {
                            Label("Delete Business", systemImage: "trash")
                        }
                    } label: {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 44, height: 44)
                            .overlay {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            .shadow(color: .black.opacity(0.1), radius: 8)
                    }
                } else {
                    Button(action: { showingReportSheet = true }) {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 44, height: 44)
                            .overlay {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                            .shadow(color: .black.opacity(0.1), radius: 8)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(headerOpacity)
                .ignoresSafeArea()
        )
    }
    
    // MARK: - Quick Info Bar
    private var quickInfoBar: some View {
        HStack(spacing: 20) {
            InfoPill(icon: "phone.fill", text: "Call") {
                callBusiness()
            }
            
            InfoPill(icon: "map.fill", text: "Directions") {
                openInAppleMaps()
            }
            
            // TODO: Uncomment when booking feature is implemented
             if business.bookingEnabled == true || isOwner {
                 InfoPill(icon: "calendar", text: "Book") {
                     showingBookingSheet = true
                 }
             }
            
            InfoPill(
                icon: isFavorite ? "heart.fill" : "heart",
                text: isFavorite ? "Saved" : "Save"
            ) {
                toggleFavorite()
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    TabButton(
                        title: tab.rawValue,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                            hapticFeedback()
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Overview Content
    private var overviewContent: some View {
        VStack(spacing: 0) {
            // Stats Cards (Only for owner)
            if isOwner {
                statsSection
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                Divider()
                    .padding(.vertical, 12)
            }
            
            // MARK: - 🆕 CLAIM BUTTON SECTION (For Non-Owners)
            if !isOwner {
                claimButtonSection
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                Divider()
                    .padding(.vertical, 12)
            }
            
            // About
            if !business.description.isEmpty {
                aboutSection
                    .padding(.horizontal, 20)
                    .padding(.top, isOwner ? 0 : 0)
                
                Divider()
                    .padding(.vertical, 12)
            }
            
            // Work Hours
            workHoursSection
                .padding(.horizontal, 20)
            
            Divider()
                .padding(.vertical, 12)
            
            // Contact Info
            contactSection
                .padding(.horizontal, 20)
            
            Divider()
                .padding(.vertical, 12)
            
            // Location Map
            locationSection
                .padding(.horizontal, 20)
            
            Divider()
                .padding(.vertical, 12)
            
            // Similar Businesses
            similarBusinessesSection
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
    }
    
    // MARK: - Reviews Content
    private var reviewsContent: some View {
        VStack(spacing: 0) {
            // Rating Summary
            ratingSummarySection
                .padding(.horizontal, 20)
                .padding(.top, 16)
            
            Divider()
                .padding(.vertical, 12)
            
            // Review Filters
            reviewFiltersSection
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            
            // Reviews List
            reviewsListSection
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
    }
    
    // MARK: - Photos Content
    private var photosContent: some View {
        VStack(spacing: 16) {
            if business.photoURLs.isEmpty {
                emptyPhotosView
            } else {
                photoGridSection
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - About Content
    private var aboutContent: some View {
        VStack(spacing: 0) {
            // Full Description
            fullDescriptionSection
                .padding(.horizontal, 20)
                .padding(.top, 16)
            
            Divider()
                .padding(.vertical, 12)
            
            // Amenities/Features (if set by owner)
            // TODO: Uncomment when amenities feature is implemented
             if business.amenities != nil && !(business.amenities?.isEmpty ?? true) {
                 amenitiesSection
                     .padding(.horizontal, 20)
            
                 Divider()
                     .padding(.vertical, 12)
             }
            
            // Business Insights (Only for owner)
            if isOwner {
                insightsSection
                    .padding(.horizontal, 20)
                
                Divider()
                    .padding(.vertical, 12)
            }
            
            // Social Media (if set by owner)
            // TODO: Uncomment when social media feature is implemented
             if business.socialMedia != nil {
                 socialMediaSection
                     .padding(.horizontal, 20)
                     .padding(.bottom, 20)
             }
        }
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analytics")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                DetailStatCard(
                    icon: "eye.fill",
                    value: "\(viewCount)",
                    label: "Views",
                    color: .blue
                )
                
                DetailStatCard(
                    icon: "heart.fill",
                    value: "\(saveCount)",
                    label: "Saves",
                    color: .red
                )
                
                DetailStatCard(
                    icon: "star.fill",
                    value: String(format: "%.1f", calculateAverageRating()),
                    label: "Rating",
                    color: .orange
                )
                
                DetailStatCard(
                    icon: "text.bubble.fill",
                    value: "\(reviewViewModel.reviews.count)",
                    label: "Reviews",
                    color: .green
                )
            }
        }
    }
    
    // MARK: - 🆕 CLAIM BUTTON SECTION
    private var claimButtonSection: some View {
        VStack(spacing: 12) {
            // If business is claimable and unclaimed
            if business.isUnclaimed {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Own this business?")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Claim it to manage your listing and reach more customers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                    }
                    
                    Button(action: { showingClaimSheet = true }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Claim This Business")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.orange.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(16)
                .background(Color.orange.opacity(0.05))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
            
            // If business has pending claim
            else if business.hasPendingClaim {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Claim Under Review")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Your claim is being reviewed by our team")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                    }
                    
                    Button(action: { showingClaimStatusSheet = true }) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Check Status")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                    }
                }
                .padding(16)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            }
            
            // If business is already claimed (by another user)
            else if business.isClaimed {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                    
                    Text("This business has been claimed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.green.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.system(size: 16, weight: .semibold))
            
            Text(business.description)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: { selectedTab = .about }) {
                Text("Read more")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    // MARK: - Work Hours Section
    private var workHoursSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Hours")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if isOwner {
                    Button(action: { showingWorkHoursEditor = true }) {
                        Text(business.workHours == nil ? "Add" : "Edit")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
            
            if let workHours = business.workHours {
                VStack(spacing: 6) {
                    WorkHourRow(day: "Mon", hours: workHours.monday, isToday: isToday(1))
                    WorkHourRow(day: "Tue", hours: workHours.tuesday, isToday: isToday(2))
                    WorkHourRow(day: "Wed", hours: workHours.wednesday, isToday: isToday(3))
                    WorkHourRow(day: "Thu", hours: workHours.thursday, isToday: isToday(4))
                    WorkHourRow(day: "Fri", hours: workHours.friday, isToday: isToday(5))
                    WorkHourRow(day: "Sat", hours: workHours.saturday, isToday: isToday(6))
                    WorkHourRow(day: "Sun", hours: workHours.sunday, isToday: isToday(0))
                }
            } else {
                Text("Hours not available")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
    }
    // MARK: - Contact Section
        private var contactSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Contact")
                    .font(.system(size: 16, weight: .semibold))
                
                VStack(spacing: 8) {
                    ContactRow(
                        icon: "phone.fill",
                        title: business.phone,
                        subtitle: "Tap to call",
                        color: .green
                    ) {
                        callBusiness()
                    }
                    
                    ContactRow(
                        icon: "location.fill",
                        title: business.address,
                        subtitle: "\(business.city), \(business.country)",
                        color: .blue
                    ) {
                        openInAppleMaps()
                    }
                }
            }
        }
        
        // MARK: - Location Section
        private var locationSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Location")
                    .font(.system(size: 16, weight: .semibold))
                
                // Interactive Map
                Map(coordinateRegion: $region, annotationItems: [business]) { business in
                    MapAnnotation(coordinate: business.coordinate) {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 32, height: 32)
                                .shadow(color: .blue.opacity(0.3), radius: 6)
                            
                            Image(systemName: "mappin.circle.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(height: 180)
                .cornerRadius(12)
                .allowsHitTesting(false)
                
                // Map Actions
                HStack(spacing: 10) {
                    MapActionButton(
                        icon: "map.fill",
                        title: "Apple Maps"
                    ) {
                        openInAppleMaps()
                    }
                    
                    MapActionButton(
                        icon: "map.circle.fill",
                        title: "Google Maps"
                    ) {
                        openInGoogleMaps()
                    }
                }
            }
        }
        
        // MARK: - Similar Businesses Section
        private var similarBusinessesSection: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Similar Places")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Button(action: {}) {
                        Text("See All")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(similarBusinesses.prefix(5)) { similarBusiness in
                            SimilarBusinessCard(business: similarBusiness)
                        }
                    }
                }
            }
        }
        
        // MARK: - Rating Summary Section
        private var ratingSummarySection: some View {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 20) {
                    // Overall Rating
                    VStack(spacing: 6) {
                        Text(String(format: "%.1f", calculateAverageRating()))
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 3) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(calculateAverageRating()) ? "star.fill" : "star")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 14))
                            }
                        }
                        
                        Text("\(reviewViewModel.reviews.count) reviews")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Rating Breakdown
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach((1...5).reversed(), id: \.self) { rating in
                            RatingBar(
                                rating: rating,
                                count: reviewViewModel.reviews.filter { Int($0.rating) == rating }.count,
                                total: reviewViewModel.reviews.count
                            )
                        }
                    }
                }
                
                // Add Review Button
                if Auth.auth().currentUser != nil && !isOwner {
                    Button(action: { showingAddReview = true }) {
                        HStack {
                            Image(systemName: "square.and.pencil")
                            Text("Write a Review")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                }
            }
        }
        
        // MARK: - Review Filters Section
        private var reviewFiltersSection: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ReviewFilter.allCases, id: \.self) { filter in
                        FilterButton(
                            title: filter.rawValue,
                            count: getFilteredCount(filter),
                            isSelected: reviewFilter == filter
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                reviewFilter = filter
                            }
                        }
                    }
                }
            }
        }
        
        // MARK: - Reviews List Section
        private var reviewsListSection: some View {
            VStack(spacing: 12) {
                if filteredReviews.isEmpty {
                    emptyReviewsView
                } else {
                    ForEach(filteredReviews.prefix(5)) { review in
                        EnhancedReviewCard(review: review)
                    }
                    
                    if filteredReviews.count > 5 {
                        Button(action: { showingAllReviews = true }) {
                            HStack {
                                Text("See All \(filteredReviews.count) Reviews")
                                    .font(.system(size: 14, weight: .semibold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                }
            }
        }
        
        // MARK: - Photo Grid Section
        private var photoGridSection: some View {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Array(business.photoURLs.enumerated()), id: \.offset) { index, url in
                    Button(action: {
                        selectedPhotoIndex = index
                        showingPhotoGallery = true
                    }) {
                        AsyncImage(url: URL(string: url)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            default:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                        }
                        .frame(height: 160)
                        .clipped()
                        .cornerRadius(10)
                    }
                }
            }
        }
        
        // MARK: - Full Description Section
        private var fullDescriptionSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Full Description")
                    .font(.system(size: 16, weight: .semibold))
                
                Text(business.description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
        }
        
        // MARK: - Amenities Section (TODO: Implement amenities feature)
        private var amenitiesSection: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Amenities")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    if isOwner {
                        Button(action: { showingAmenitiesEditor = true }) {
                            Text("Edit")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // TODO: Implement amenities storage in Business model
                // Add: var amenities: [String]? to Business model
                // Implement AmenitiesEditorView to allow owner to set amenities
                if let amenities = business.amenities, !amenities.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(amenities, id: \.self) { amenity in
                            AmenityItem(title: amenity)
                        }
                    }
                }
            }
        }
        
        
        // MARK: - Insights Section
        private var insightsSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Business Insights")
                    .font(.system(size: 16, weight: .semibold))
                
                VStack(spacing: 8) {
                    DetailInsightRow(icon: "eye.fill", title: "Total Views", value: "\(viewCount)", trend: "+12%")
                    DetailInsightRow(icon: "heart.fill", title: "Total Saves", value: "\(saveCount)", trend: "+8%")
                    DetailInsightRow(icon: "arrow.up.right.circle.fill", title: "Direction Requests", value: "156", trend: "+24%")
                    DetailInsightRow(icon: "phone.fill", title: "Call Clicks", value: "89", trend: "+15%")
                }
            }
        }
        
        // MARK: - Social Media Section (TODO: Implement social media feature)
        private var socialMediaSection: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Connect")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    if isOwner {
                        Button(action: { showingSocialMediaEditor = true }) {
                            Text("Edit")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // TODO: Implement social media storage in Business model
                // Add: var socialMedia: SocialMedia? to Business model
                // struct SocialMedia { var website: String?, facebook: String?, instagram: String?, youtube: String? }
                // Implement SocialMediaEditorView to allow owner to set social links
                if let socialMedia = business.socialMedia {
                    HStack(spacing: 14) {
                        if let website = socialMedia.website, !website.isEmpty {
                            SocialButton(icon: "globe", color: .blue) {
                                openURL(website)
                            }
                        }
                        if let facebook = socialMedia.facebook, !facebook.isEmpty {
                            SocialButton(icon: "f.square.fill", color: Color(hex: "1877F2")) {
                                openURL(facebook)
                            }
                        }
                        if let instagram = socialMedia.instagram, !instagram.isEmpty {
                            SocialButton(icon: "camera.fill", color: Color(hex: "E4405F")) {
                                openURL(instagram)
                            }
                        }
                        if let youtube = socialMedia.youtube, !youtube.isEmpty {
                            SocialButton(icon: "play.rectangle.fill", color: .red) {
                                openURL(youtube)
                            }
                        }
                    }
                }
            }
        }
        
        
        // MARK: - Empty States
        private var emptyReviewsView: some View {
            VStack(spacing: 12) {
                Image(systemName: "star.circle")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                
                Text("No reviews yet")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("Be the first to review this business!")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
        
        private var emptyPhotosView: some View {
            VStack(spacing: 12) {
                Image(systemName: "photo.circle")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                
                Text("No photos yet")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
        
        // MARK: - Placeholder
        private var placeholderImage: some View {
            Rectangle()
                .fill(Color.blue.opacity(0.2))
                .overlay {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.white.opacity(0.5))
                }
        }
    }
extension BusinessDetailView {
    // MARK: - Computed Properties
    
    var isFavorite: Bool {
        guard let businessId = business.id else { return false }
        return favoriteViewModel.isFavorite(businessId: businessId)
    }
    
    var isBusinessOpen: Bool {
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
    
    var similarBusinesses: [Business] {
        businessViewModel.businesses
            .filter { $0.category == business.category && $0.id != business.id }
            .prefix(10)
            .map { $0 }
    }
    
    var filteredReviews: [Review] {
        var reviews = reviewViewModel.reviews
        
        switch reviewFilter {
        case .all:
            break
        case .recent:
            reviews.sort { $0.createdAt > $1.createdAt }
        case .highRated:
            reviews = reviews.filter { $0.rating >= 4 }
        case .lowRated:
            reviews = reviews.filter { $0.rating <= 2 }
        case .withPhotos:
            break
        }
        
        return reviews
    }
    
    // MARK: - Helper Functions
    
    func calculateAverageRating() -> Double {
        guard !reviewViewModel.reviews.isEmpty else { return 0.0 }
        let total = reviewViewModel.reviews.reduce(0.0) { $0 + $1.rating }
        return total / Double(reviewViewModel.reviews.count)
    }
    
    func isToday(_ weekday: Int) -> Bool {
        let today = Calendar.current.component(.weekday, from: Date())
        return (today == weekday + 1) || (today == 1 && weekday == 0)
    }
    
    func getFilteredCount(_ filter: ReviewFilter) -> Int {
        switch filter {
        case .all: return reviewViewModel.reviews.count
        case .recent: return reviewViewModel.reviews.count
        case .highRated: return reviewViewModel.reviews.filter { $0.rating >= 4 }.count
        case .lowRated: return reviewViewModel.reviews.filter { $0.rating <= 2 }.count
        case .withPhotos: return 0
        }
    }
    
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    func refreshData() async {
        isRefreshing = true
        reviewViewModel.fetchReviews(for: business.id ?? "")
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
    }
    
    func trackView() {
        viewCount = Int.random(in: 100...500)
        saveCount = Int.random(in: 20...150)
    }
    
    func deleteBusiness() {
        businessViewModel.deleteBusiness(business) { success, message in
            alertMessage = message
            showingAlert = true
        }
    }
    
    func callBusiness() {
        if let url = URL(string: "tel://\(business.phone.replacingOccurrences(of: " ", with: ""))") {
            UIApplication.shared.open(url)
        }
    }
    
    func openInAppleMaps() {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: business.coordinate))
        mapItem.name = business.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    func openInGoogleMaps() {
        let coordinate = business.coordinate
        let googleMapsURL = "comgooglemaps://?q=\(coordinate.latitude),\(coordinate.longitude)"
        let googleMapsWebURL = "https://www.google.com/maps/search/?api=1&query=\(coordinate.latitude),\(coordinate.longitude)"
        
        if let url = URL(string: googleMapsURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: googleMapsWebURL) {
            UIApplication.shared.open(url)
        }
    }
    
    func shareBusinessAction() {
        let text = """
        Check out \(business.name)!
        
        ⭐️ \(String(format: "%.1f", calculateAverageRating())) (\(reviewViewModel.reviews.count) reviews)
        📍 \(business.address), \(business.city)
        📞 \(business.phone)
        
        Category: \(business.category)
        """
        
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            var topController = rootViewController
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            activityVC.popoverPresentationController?.sourceView = topController.view
            topController.present(activityVC, animated: true)
        }
    }
    
    func toggleFavorite() {
        guard let businessId = business.id else { return }
        
        hapticFeedback(.medium)
        
        favoriteViewModel.toggleFavorite(businessId: businessId) { success, message in
            if !success {
                alertMessage = message
                showingAlert = true
            }
        }
    }
    
    func openURL(_ urlString: String) {
        var urlToOpen = urlString
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlToOpen = "https://\(urlString)"
        }
        
        if let url = URL(string: urlToOpen) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Floating Action Buttons
    var floatingActionButtons: some View {
        VStack(spacing: 10) {
            FloatingActionButton(
                icon: isFavorite ? "heart.fill" : "heart",
                color: isFavorite ? .red : .gray
            ) {
                toggleFavorite()
            }
            
            FloatingActionButton(icon: "phone.fill", color: .green) {
                callBusiness()
            }
            
            FloatingActionButton(icon: "map.fill", color: .blue) {
                openInAppleMaps()
            }
        }
    }
}

// MARK: - Supporting Components

struct InfoPill: View {
    let icon: String
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(DetailScaleButtonStyle())
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? Color.blue
                        : Color(.systemGray6)
                )
                .cornerRadius(20)
        }
        .buttonStyle(DetailScaleButtonStyle())
    }
}

struct DetailStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct WorkHourRow: View {
    let day: String
    let hours: DayHours
    let isToday: Bool
    
    var body: some View {
        HStack {
            Text(day)
                .font(.system(size: 13, weight: isToday ? .semibold : .regular))
                .foregroundColor(isToday ? .blue : .primary)
                .frame(width: 45, alignment: .leading)
            
            Spacer()
            
            if hours.isOpen {
                Text("\(hours.openTime) - \(hours.closeTime)")
                    .font(.system(size: 13))
                    .foregroundColor(isToday ? .blue : .secondary)
            } else {
                Text("Closed")
                    .font(.system(size: 13))
                    .foregroundColor(.red)
            }
        }
    }
}

struct ContactRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MapActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct SimilarBusinessCard: View {
    let business: Business
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: URL(string: business.photoURLs.first ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle().fill(Color.gray.opacity(0.3))
                }
            }
            .frame(width: 140, height: 100)
            .clipped()
            .cornerRadius(10)
            
            Text(business.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 10))
                Text(String(format: "%.1f", business.rating))
                    .font(.system(size: 11))
                    .fontWeight(.medium)
            }
        }
        .frame(width: 140)
    }
}

struct RatingBar: View {
    let rating: Int
    let count: Int
    let total: Int
    
    var percentage: Double {
        total == 0 ? 0 : Double(count) / Double(total)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Text("\(rating)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 10)
            
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundColor(.orange)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 5)
                        .cornerRadius(2.5)
                    
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: geometry.size.width * percentage, height: 5)
                        .cornerRadius(2.5)
                }
            }
            .frame(height: 5)
            
            Text("\(count)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)
        }
    }
}

struct FilterButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text("(\(count))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                isSelected
                    ? Color.blue
                    : Color(.systemGray6)
            )
            .cornerRadius(18)
        }
        .buttonStyle(DetailScaleButtonStyle())
    }
}

struct EnhancedReviewCard: View {
    let review: Review
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(Color.blue.opacity(0.8))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Text(String(review.userName.prefix(1)))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(review.userName)
                        .font(.system(size: 14, weight: .semibold))
                    
                    HStack(spacing: 3) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(review.rating) ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                        }
                        Text("• \(review.createdAt, style: .relative)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            Text(review.comment)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// TODO: Uncomment when amenities feature is implemented

struct AmenityItem: View {
    let title: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 14))
            
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
}


struct DetailInsightRow: View {
    let icon: String
    let title: String
    let value: String
    let trend: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.system(size: 14))
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(trend)
                .font(.system(size: 11))
                .foregroundColor(.green)
        }
        .padding(.vertical, 6)
    }
}

// TODO: Uncomment when social media feature is implemented

struct SocialButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .cornerRadius(10)
        }
    }
}


struct FloatingActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .cornerRadius(25)
                .shadow(color: color.opacity(0.3), radius: 8, y: 4)
        }
    }
}

struct DetailScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct DetailScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Enhanced Report Business View

struct ReportBusinessView: View {
    let business: Business
    @Environment(\.dismiss) var dismiss
    @State private var selectedReason = "Inappropriate Content"
    @State private var details = ""
    @State private var isSubmitting = false
    
    let reportReasons = [
        "Inappropriate Content",
        "Spam or Scam",
        "Incorrect Information",
        "Duplicate Listing",
        "Permanently Closed",
        "Copyright Violation",
        "Offensive Content",
        "Other"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Help us understand what's wrong")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                } header: {
                    Text("Report Issue")
                }
                
                Section {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(reportReasons, id: \.self) { reason in
                            Text(reason).tag(reason)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Issue Type")
                }
                
                Section {
                    TextEditor(text: $details)
                        .frame(height: 120)
                } header: {
                    Text("Additional Details")
                } footer: {
                    Text("Please provide specific information about the issue")
                        .font(.caption)
                }
                
                Section {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(.blue)
                            Text(business.name)
                                .font(.system(size: 14, weight: .medium))
                        }
                        
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.green)
                            Text(business.address)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } header: {
                    Text("Business Information")
                }
            }
            .navigationTitle("Report Business")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: submitReport) {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Submit")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(details.isEmpty || isSubmitting)
                }
            }
        }
    }
    
    func submitReport() {
        isSubmitting = true
        // Handle report submission
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSubmitting = false
            dismiss()
        }
    }
}

// MARK: - Placeholder Views

struct PhotoGalleryView: View {
    let photos: [String]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedIndex) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, url in
                    AsyncImage(url: URL(string: url)) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct AllReviewsView: View {
    let business: Business
    let reviews: [Review]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(reviews) { review in
                        EnhancedReviewCard(review: review)
                    }
                }
                .padding()
            }
            .navigationTitle("All Reviews")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// TODO: Uncomment when booking feature is implemented

struct BookingView: View {
    let business: Business
    @Environment(\.dismiss) var dismiss
    @State private var selectedDate = Date()
    @State private var selectedTime = "10:00"
    @State private var partySize = 2
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    Picker("Time", selection: $selectedTime) {
                        ForEach(["09:00", "10:00", "11:00", "12:00", "13:00", "14:00", "15:00"], id: \.self) {
                            Text($0)
                        }
                    }
                    Stepper("Party Size: \(partySize)", value: $partySize, in: 1...20)
                }
            }
            .navigationTitle("Book a Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Confirm") {
                        dismiss()
                    }
                }
            }
        }
    }
}


// MARK: - Placeholder Editor Views (To be implemented later)

// TODO: Uncomment and implement when booking feature is ready

struct BookingSettingsView: View {
    let business: Business
    let businessViewModel: BusinessViewModel
    @Environment(\.dismiss) var dismiss
    
    // TODO: Implement booking settings functionality
    // - Toggle to enable/disable booking
    // - Set available time slots
    // - Configure booking duration
    // - Set maximum party size
    // - Add booking confirmation settings
    // - Integration with calendar/notification system
    
    var body: some View {
        NavigationView {
            Form {
                Section("Booking Settings") {
                    Toggle("Enable Booking", isOn: .constant(false))
                    Text("Configure booking settings here")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Booking Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}


// TODO: Uncomment and implement when amenities feature is ready

struct AmenitiesEditorView: View {
    let business: Business
    let businessViewModel: BusinessViewModel
    @Environment(\.dismiss) var dismiss
    
    // TODO: Implement amenities editor functionality
    // - Allow owner to select from predefined amenities
    // - Add custom amenities
    // - Save amenities to Business model
    // Common amenities: WiFi, Parking, Card Payment, Accessible, Outdoor Seating, AC, Pet Friendly, etc.
    
    var body: some View {
        NavigationView {
            Form {
                Section("Amenities") {
                    Text("Configure amenities here")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Amenities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}


// TODO: Uncomment and implement when social media feature is ready

struct SocialMediaEditorView: View {
    let business: Business
    let businessViewModel: BusinessViewModel
    @Environment(\.dismiss) var dismiss
    
    // TODO: Implement social media editor functionality
    // - Text fields for each social platform
    // - URL validation
    // - Save to Business model
    // - Support: Website, Facebook, Instagram, YouTube, Twitter, LinkedIn, TikTok
    
    var body: some View {
        NavigationView {
            Form {
                Section("Social Media") {
                    TextField("Website", text: .constant(""))
                    TextField("Facebook", text: .constant(""))
                    TextField("Instagram", text: .constant(""))
                    TextField("YouTube", text: .constant(""))
                }
            }
            .navigationTitle("Social Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
