import SwiftUI
import MapKit
import FirebaseAuth

struct BusinessDetailView: View {
    let business: Business
    
    @State private var region: MKCoordinateRegion
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingWorkHoursEditor = false
    @State private var showingShareSheet = false
    @State private var showingAddReview = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject var businessViewModel: BusinessViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var reviewViewModel = ReviewViewModel()
    
    var isOwner: Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return false
        }
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
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Image
                    HeroImageHeader(photoURLs: business.photoURLs)
                    
                    VStack(spacing: AppSpacing.lg) {
                        // Header Info
                        headerSection
                        
                        // Action Buttons
                        actionButtonsSection
                        
                        Divider()
                            .padding(.horizontal, AppSpacing.md)
                        
                        // About Section
                        aboutSection
                        
                        Divider()
                            .padding(.horizontal, AppSpacing.md)
                        
                        // Contact Info
                        contactSection
                        
                        // Work Hours
                        if business.workHours != nil || isOwner {
                            Divider()
                                .padding(.horizontal, AppSpacing.md)
                            
                            workHoursSection
                        }
                        
                        Divider()
                            .padding(.horizontal, AppSpacing.md)
                        
                        // Location
                        locationSection
                        
                        Divider()
                            .padding(.horizontal, AppSpacing.md)
                        
                        // Reviews
                        reviewsSection
                    }
                    .padding(.vertical, AppSpacing.lg)
                }
            }
            .background(AppColors.background)
            .ignoresSafeArea(edges: .top)
            
            // Back Button
            Button(action: {
                dismiss()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.top, 50)
            .padding(.leading, AppSpacing.md)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingWorkHoursEditor) {
            WorkHoursEditorView(business: business, businessViewModel: businessViewModel)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditBusinessView(business: business, businessViewModel: businessViewModel)
        }
        .sheet(isPresented: $showingAddReview) {
            AddReviewView(business: business, reviewViewModel: reviewViewModel)
        }
        .alert("Delete Business", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteBusiness()
            }
        } message: {
            Text("Are you sure you want to delete '\(business.name)'? This action cannot be undone.")
        }
        .alert("Message", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {
                if alertMessage.contains("deleted successfully") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Header Section
    
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    // Category Badge
                    Text(business.category)
                        .font(AppFonts.captionBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColors.categoryColor(for: business.category))
                        .cornerRadius(AppRadius.sm)
                    
                    // Business Name
                    Text(business.name)
                        .font(AppFonts.title1)
                        .foregroundColor(AppColors.textPrimary)
                    
                    // Rating
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.starYellow)
                            Text(String(format: "%.1f", business.rating))
                                .font(AppFonts.bodyBold)
                                .foregroundColor(AppColors.textPrimary)
                        }
                        
                        Text("•")
                            .foregroundColor(AppColors.textTertiary)
                        
                        Text("\(business.reviewCount) reviews")
                            .font(AppFonts.callout)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Spacer()
                
                // Owner Actions
                if isOwner {
                    Menu {
                        Button(action: {
                            showingEditSheet = true
                        }) {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive, action: {
                            showingDeleteAlert = true
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(AppColors.surface)
                                .frame(width: 40, height: 40)
                                .shadow(color: AppShadow.small, radius: 4, x: 0, y: 2)
                            
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - Action Buttons Section
    
    var actionButtonsSection: some View {
        HStack(spacing: AppSpacing.md) {
            ActionButton(
                icon: "phone.fill",
                title: "Call",
                color: AppColors.success
            ) {
                callBusiness()
            }
            
            ActionButton(
                icon: "map.fill",
                title: "Directions",
                color: AppColors.primary
            ) {
                openInAppleMaps()
            }
            
            ActionButton(
                icon: "square.and.arrow.up",
                title: "Share",
                color: AppColors.accent
            ) {
                shareBusiness()
            }
            
            ActionButton(
                icon: "heart",
                title: "Save",
                color: AppColors.error
            ) {
                // TODO: Add to favorites
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - About Section
    
    var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "About", icon: "info.circle.fill")
            
            Text(business.description)
                .font(AppFonts.body)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Contact Section
    
    var contactSection: some View {
        VStack(spacing: AppSpacing.sm) {
            SectionHeader(title: "Contact Information", icon: "phone.circle.fill")
            
            VStack(spacing: AppSpacing.sm) {
                InfoRow(
                    icon: "phone.fill",
                    title: business.phone,
                    subtitle: "Tap to call",
                    color: AppColors.success
                ) {
                    callBusiness()
                }
                
                InfoRow(
                    icon: "location.fill",
                    title: business.address,
                    subtitle: "\(business.city), \(business.country)",
                    color: AppColors.primary
                ) {
                    openInAppleMaps()
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Work Hours Section
    
    var workHoursSection: some View {
        VStack(spacing: AppSpacing.sm) {
            SectionHeader(
                title: "Work Hours",
                icon: "clock.fill",
                actionTitle: isOwner ? (business.workHours == nil ? "Add" : "Edit") : nil
            ) {
                showingWorkHoursEditor = true
            }
            
            if let workHours = business.workHours {
                VStack(spacing: 0) {
                    WorkHoursDisplayView(workHours: workHours)
                }
                .padding(AppSpacing.md)
                .background(AppColors.surface)
                .cornerRadius(AppRadius.md)
                .padding(.horizontal, AppSpacing.md)
            } else if isOwner {
                Button(action: {
                    showingWorkHoursEditor = true
                }) {
                    HStack {
                        Image(systemName: "clock.badge.plus")
                        Text("Add Work Hours")
                    }
                    .font(AppFonts.callout)
                    .foregroundColor(AppColors.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.primary.opacity(0.1))
                    .cornerRadius(AppRadius.md)
                }
                .padding(.horizontal, AppSpacing.md)
            }
        }
    }
    
    // MARK: - Location Section
    
    var locationSection: some View {
        VStack(spacing: AppSpacing.sm) {
            SectionHeader(title: "Location", icon: "map.fill")
            
            VStack(spacing: AppSpacing.sm) {
                // Map
                Map(coordinateRegion: $region, annotationItems: [business]) { business in
                    MapMarker(coordinate: business.coordinate, tint: .red)
                }
                .frame(height: 200)
                .cornerRadius(AppRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(colorScheme == .dark ? AppColors.border.opacity(0.2) : Color.clear, lineWidth: 1)
                )
                
                // Map Actions
                HStack(spacing: AppSpacing.sm) {
                    Button(action: {
                        openInAppleMaps()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Apple Maps")
                                .font(AppFonts.callout)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.primary)
                        .cornerRadius(AppRadius.md)
                    }
                    
                    Button(action: {
                        openInGoogleMaps()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "map.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Google Maps")
                                .font(AppFonts.callout)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(AppColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.primary.opacity(0.1))
                        .cornerRadius(AppRadius.md)
                    }
                }
                
                // Coordinates
                HStack {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.primary)
                    Text(String(format: "%.4f, %.4f", business.latitude, business.longitude))
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Reviews Section
    
    var reviewsSection: some View {
        VStack(spacing: AppSpacing.sm) {
            SectionHeader(
                title: "Reviews (\(business.reviewCount))",
                icon: "star.fill",
                actionTitle: reviewViewModel.reviews.count > 3 ? "See All" : nil
            ) {
                // TODO: Show all reviews
            }
            
            if reviewViewModel.reviews.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star.circle")
                        .font(.system(size: 50))
                        .foregroundColor(AppColors.textTertiary)
                    
                    Text("No reviews yet")
                        .font(AppFonts.callout)
                        .foregroundColor(AppColors.textSecondary)
                    
                    if Auth.auth().currentUser != nil {
                        Text("Be the first to review!")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(reviewViewModel.reviews.prefix(3)) { review in
                        SimpleReviewCard(review: review)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
            
            // Add Review Button
            if Auth.auth().currentUser != nil && !isOwner {
                Button(action: {
                    showingAddReview = true
                }) {
                    HStack {
                        Image(systemName: "square.and.pencil")
                        Text("Write a Review")
                    }
                    .font(AppFonts.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.primary)
                    .cornerRadius(AppRadius.md)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
            }
        }
        .onAppear {
            reviewViewModel.fetchReviews(for: business.id ?? "")
        }
    }
    
    // MARK: - Helper Functions
    
    func deleteBusiness() {
        businessViewModel.deleteBusiness(business) { success, message in
            alertMessage = message
            showingAlert = true
        }
    }
    
    func callBusiness() {
        if let url = URL(string: "tel://\(business.phone)") {
            UIApplication.shared.open(url)
        }
    }
    
    func openInAppleMaps() {
        let coordinate = business.coordinate
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = business.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
    
    func openInGoogleMaps() {
        let coordinate = business.coordinate
        let googleMapsURL = "comgooglemaps://?q=\(coordinate.latitude),\(coordinate.longitude)&center=\(coordinate.latitude),\(coordinate.longitude)&zoom=16"
        let googleMapsWebURL = "https://www.google.com/maps/search/?api=1&query=\(coordinate.latitude),\(coordinate.longitude)"
        
        if let url = URL(string: googleMapsURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: googleMapsWebURL) {
            UIApplication.shared.open(url)
        }
    }
    
    func shareBusiness() {
        let text = """
        Check out \(business.name) on Javid!
        
        📍 \(business.address), \(business.city)
        ⭐️ \(String(format: "%.1f", business.rating)) stars (\(business.reviewCount) reviews)
        📞 \(business.phone)
        
        Category: \(business.category)
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            activityVC.popoverPresentationController?.permittedArrowDirections = []
            rootVC.present(activityVC, animated: true)
        }
    }
    
    // MARK: - Simple Review Card
    struct SimpleReviewCard: View {
        let review: Review
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 12) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(AppColors.primary.opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("User")
                            .font(AppFonts.bodyBold)
                            .foregroundColor(AppColors.textPrimary)
                        
                        HStack(spacing: 4) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(review.rating) ? "star.fill" : "star")
                                    .font(.system(size: 12))
                                    .foregroundColor(index < Int(review.rating) ? AppColors.starYellow : AppColors.textTertiary)
                            }
                            
                            Text("•")
                                .foregroundColor(AppColors.textTertiary)
                                .font(AppFonts.caption)
                            
                            Text(review.createdAt.timeAgo())
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    Spacer()
                }
                
                // Review Text
                Text(review.comment)
                    .font(AppFonts.callout)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(4)
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .cornerRadius(AppRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(colorScheme == .dark ? AppColors.border.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
    }
}
