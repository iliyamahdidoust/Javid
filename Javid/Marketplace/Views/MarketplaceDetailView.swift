import SwiftUI
import MapKit
import FirebaseAuth
import FirebaseFirestore

struct MarketplaceDetailView: View {
    let item: MarketplaceItem
    @ObservedObject var marketplaceViewModel: MarketplaceViewModel
    
    @State private var region: MKCoordinateRegion
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingShareSheet = false
    @State private var showingMarkAsSoldAlert = false
    
    // ✅ NEW: Message sending states
    @StateObject private var messagingViewModel = MessagingViewModel()
    @State private var isSendingMessage = false
    @State private var messageSent = false
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var isOwner: Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return false
        }
        return item.sellerId == currentUserId
    }
    
    var isSaved: Bool {
        guard let itemId = item.id else { return false }
        return marketplaceViewModel.isSaved(itemId: itemId)
    }
    
    init(item: MarketplaceItem, marketplaceViewModel: MarketplaceViewModel) {
        self.item = item
        self.marketplaceViewModel = marketplaceViewModel
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Image Section
                    HeroImageHeader(photoURLs: item.photoURLs)
                    
                    VStack(spacing: AppSpacing.lg) {
                        // Header Section
                        headerSection
                        
                        // ✅ NEW: Status Section (show for owners)
                        if isOwner {
                            Divider()
                                .padding(.horizontal, AppSpacing.md)
                            
                            statusSection
                                .padding(.horizontal, AppSpacing.md)
                        }
                        
                        Divider()
                            .padding(.horizontal, AppSpacing.md)
                        
                        // Description Section
                        descriptionSection
                        
                        Divider()
                            .padding(.horizontal, AppSpacing.md)
                        
                        // Details Section
                        detailsSection
                        
                        Divider()
                            .padding(.horizontal, AppSpacing.md)
                        
                        // Location Section
                        locationSection
                        
                        Divider()
                            .padding(.horizontal, AppSpacing.md)
                        
                        // Seller Section
                        sellerSection
                        
                        // Owner Insights Section (ONLY visible to owner)
                        if isOwner {
                            Divider()
                                .padding(.horizontal, AppSpacing.md)
                            
                            ownerInsightsSection
                        }
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
        .onAppear {
            // Increment view count for non-owners
            if !isOwner, let itemId = item.id {
                marketplaceViewModel.incrementViewCount(for: itemId)
            }
            
            // ✅ NEW: Auto-update status after 5 minutes
            if isOwner && item.listingStatus == "under_review" {
                let timeElapsed = Date().timeIntervalSince(item.statusUpdatedAt)
                if timeElapsed >= 300 { // 5 minutes
                    updateStatusToActive()
                } else {
                    // Schedule update
                    let remainingTime = 300 - timeElapsed
                    DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
                        updateStatusToActive()
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditMarketplaceItemView(item: item, marketplaceViewModel: marketplaceViewModel)
        }
        .alert("Delete Item", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("Are you sure you want to delete '\(item.title)'? This action cannot be undone.")
        }
        .alert("Mark as Sold", isPresented: $showingMarkAsSoldAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Mark as Sold", role: .destructive) {
                markAsSold()
            }
        } message: {
            Text("Mark this item as sold? It will still be visible but marked as unavailable.")
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
        .overlay {
            // ✅ NEW: Loading overlay when sending message
            if isSendingMessage {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Sending message...")
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text(item.title)
                        .font(AppFonts.title1)
                        .foregroundColor(AppColors.textPrimary)
                    
                    // Price
                    Text(item.formattedPrice)
                        .font(AppFonts.largeTitle)
                        .foregroundColor(AppColors.primary)
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
                        
                        if !item.isSold {
                            Button(action: {
                                showingMarkAsSoldAlert = true
                            }) {
                                Label("Mark as Sold", systemImage: "checkmark.circle")
                            }
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
            
            // Condition Badge
            HStack(spacing: 8) {
                Text(item.condition.rawValue)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.surface)
                    .cornerRadius(AppRadius.sm)
                
                Text(item.category.rawValue)
                    .font(AppFonts.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.categoryColor(for: item.category.rawValue))
                    .cornerRadius(AppRadius.sm)
                
                if item.isSold {
                    Text("SOLD")
                        .font(AppFonts.captionBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .cornerRadius(AppRadius.sm)
                }
            }
            
            // ✅ UPDATED: Direct Message Box (Only for non-owners)
            if !isOwner {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.vertical, 16)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.primary)
                        
                        Text("Message seller")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Spacer()
                    }
                    .padding(.bottom, 12)
                    
                    HStack(spacing: 12) {
                        Text("Hello, is this still available?")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.95))
                            )
                        
                        // ✅ UPDATED: Send button changes to "Sent" with green color after sending
                        Button(action: sendDirectMessage) {
                            HStack(spacing: 6) {
                                if messageSent {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("Sent")
                                        .font(.system(size: 17, weight: .semibold))
                                } else {
                                    Text("Send")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(messageSent ? AppColors.success : AppColors.primary)
                            .cornerRadius(12)
                        }
                        .disabled(isSendingMessage || messageSent)
                    }
                    
                    Divider()
                        .padding(.top, 16)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - Status Section
    
    var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Listing Status")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: statusIcon)
                        .font(.system(size: 20))
                        .foregroundColor(statusColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(statusDescription)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
            }
            .padding(16)
            .background(statusColor.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(statusColor.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    var statusText: String {
        switch item.listingStatus {
        case "under_review":
            return "Under Review"
        case "active":
            return "Active"
        case "sold":
            return "Sold"
        default:
            return "Unknown"
        }
    }
    
    var statusDescription: String {
        switch item.listingStatus {
        case "under_review":
            let timeRemaining = max(0, 300 - Int(Date().timeIntervalSince(item.statusUpdatedAt)))
            let minutes = timeRemaining / 60
            let seconds = timeRemaining % 60
            if timeRemaining > 0 {
                return "Your listing is being reviewed • \(minutes):\(String(format: "%02d", seconds)) remaining"
            } else {
                return "Review complete • Activating..."
            }
        case "active":
            return "Your listing is live and visible to buyers"
        case "sold":
            return "This item has been sold"
        default:
            return ""
        }
    }
    
    var statusColor: Color {
        switch item.listingStatus {
        case "under_review":
            return AppColors.warning
        case "active":
            return AppColors.success
        case "sold":
            return AppColors.textSecondary
        default:
            return AppColors.textTertiary
        }
    }
    
    var statusIcon: String {
        switch item.listingStatus {
        case "under_review":
            return "clock.fill"
        case "active":
            return "checkmark.circle.fill"
        case "sold":
            return "tag.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    // MARK: - Description Section
    
    var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Description", icon: "text.alignleft")
            
            Text(item.description)
                .font(AppFonts.body)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Details Section
    
    var detailsSection: some View {
        VStack(spacing: AppSpacing.sm) {
            SectionHeader(title: "Details", icon: "info.circle.fill")
            
            VStack(spacing: AppSpacing.sm) {
                InfoRow(
                    icon: "tag.fill",
                    title: "Category",
                    subtitle: item.category.rawValue,
                    color: AppColors.primary
                )
                
                InfoRow(
                    icon: "star.fill",
                    title: "Condition",
                    subtitle: item.condition.rawValue,
                    color: AppColors.warning
                )
                
                InfoRow(
                    icon: "calendar",
                    title: "Posted",
                    subtitle: item.createdAt.timeAgo(),
                    color: AppColors.info
                )
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Location Section
    
    var locationSection: some View {
        VStack(spacing: AppSpacing.sm) {
            SectionHeader(title: "Location", icon: "map.fill")
            
            VStack(spacing: AppSpacing.sm) {
                // Map
                Map(coordinateRegion: $region, annotationItems: [item]) { item in
                    MapMarker(coordinate: CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude), tint: .red)
                }
                .frame(height: 200)
                .cornerRadius(AppRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(colorScheme == .dark ? AppColors.border.opacity(0.2) : Color.clear, lineWidth: 1)
                )
                
                // Location Info
                HStack {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.primary)
                    Text(item.location)
                        .font(AppFonts.callout)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Seller Section
    
    var sellerSection: some View {
        VStack(spacing: AppSpacing.sm) {
            SectionHeader(title: "Seller", icon: "person.fill")
            
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Text(item.sellerName.prefix(1).uppercased())
                        .font(AppFonts.title3)
                        .foregroundColor(AppColors.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.sellerName)
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Spacer()
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .cornerRadius(AppRadius.md)
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Owner Insights Section (ONLY FOR OWNER)
    
    var ownerInsightsSection: some View {
        VStack(spacing: AppSpacing.md) {
            SectionHeader(title: "Listing Insights", icon: "chart.bar.fill")
            
            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: AppSpacing.md) {
                // Views
                MarketplaceStatCard(
                    icon: "eye.fill",
                    value: "\(item.viewCount)",
                    label: "Views",
                    color: AppColors.info
                )
                
                // Saves
                MarketplaceStatCard(
                    icon: "heart.fill",
                    value: "\(item.savedCount)",
                    label: "Saves",
                    color: AppColors.error
                )
                
                // Days Listed
                MarketplaceStatCard(
                    icon: "calendar",
                    value: "\(daysListed)",
                    label: "Days Listed",
                    color: AppColors.success
                )
                
                // Engagement Rate
                MarketplaceStatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    value: engagementRate,
                    label: "Engagement",
                    color: AppColors.warning
                )
            }
            .padding(.horizontal, AppSpacing.md)
            
            // Performance Insights
            VStack(spacing: AppSpacing.sm) {
                InsightRow(
                    icon: "star.fill",
                    title: "Performance",
                    value: performanceRating,
                    color: performanceColor
                )
                
                InsightRow(
                    icon: "clock.fill",
                    title: "Average Views/Day",
                    value: viewsPerDay,
                    color: AppColors.info
                )
                
                InsightRow(
                    icon: "percentage",
                    title: "Save Rate",
                    value: saveRate,
                    color: AppColors.primary
                )
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .cornerRadius(AppRadius.md)
            .padding(.horizontal, AppSpacing.md)
            
            // Quick Actions
            VStack(spacing: AppSpacing.sm) {
                Text("Quick Actions")
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.md)
                
                VStack(spacing: AppSpacing.sm) {
                    // Share Listing
                    Button(action: shareListing) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.primary)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Share Listing")
                                    .font(AppFonts.callout)
                                    .foregroundColor(AppColors.textPrimary)
                                Text("Share on social media or copy link")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.surface)
                        .cornerRadius(AppRadius.md)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Boost Listing (Future Feature)
                    Button(action: {
                        alertMessage = "Boost feature coming soon! This will promote your listing to more viewers."
                        showingAlert = true
                    }) {
                        HStack {
                            Image(systemName: "megaphone.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.warning)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Boost Listing")
                                        .font(AppFonts.callout)
                                        .foregroundColor(AppColors.textPrimary)
                                    Text("NEW")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppColors.warning)
                                        .cornerRadius(4)
                                }
                                Text("Get more visibility for your listing")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.surface)
                        .cornerRadius(AppRadius.md)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Edit Listing
                    Button(action: {
                        showingEditSheet = true
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.success)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Edit Listing")
                                    .font(AppFonts.callout)
                                    .foregroundColor(AppColors.textPrimary)
                                Text("Update price, photos, or description")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.surface)
                        .cornerRadius(AppRadius.md)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Mark as Sold / Relist
                    if item.isSold {
                        Button(action: relistItem) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppColors.primary)
                                    .frame(width: 40)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Relist Item")
                                        .font(AppFonts.callout)
                                        .foregroundColor(AppColors.textPrimary)
                                    Text("Make this listing active again")
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(AppSpacing.md)
                            .background(AppColors.surface)
                            .cornerRadius(AppRadius.md)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Button(action: {
                            showingMarkAsSoldAlert = true
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppColors.success)
                                    .frame(width: 40)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Mark as Sold")
                                        .font(AppFonts.callout)
                                        .foregroundColor(AppColors.textPrimary)
                                    Text("Item has been sold")
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(AppSpacing.md)
                            .background(AppColors.surface)
                            .cornerRadius(AppRadius.md)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Delete Listing
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.error)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Delete Listing")
                                    .font(AppFonts.callout)
                                    .foregroundColor(AppColors.error)
                                Text("Permanently remove this listing")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.surface)
                        .cornerRadius(AppRadius.md)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, AppSpacing.md)
            }
            
            // Tips for Better Performance
            if viewsPerDayValue < 5 || saveRateValue < 10 {
                VStack(spacing: AppSpacing.sm) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(AppColors.warning)
                        Text("Tips to Improve Performance")
                            .font(AppFonts.bodyBold)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        if viewsPerDayValue < 5 {
                            TipRow(text: "Add more high-quality photos to attract viewers")
                            TipRow(text: "Write a detailed description with keywords")
                            TipRow(text: "Share your listing on social media")
                        }
                        
                        if saveRateValue < 10 {
                            TipRow(text: "Consider adjusting your price to be more competitive")
                            TipRow(text: "Highlight unique features in your description")
                            TipRow(text: "Respond quickly to inquiries")
                        }
                    }
                }
                .padding(AppSpacing.md)
                .background(AppColors.warning.opacity(0.1))
                .cornerRadius(AppRadius.md)
                .padding(.horizontal, AppSpacing.md)
            }
        }
    }
    
    // MARK: - Computed Properties for Insights
    
    var daysListed: Int {
        let days = Calendar.current.dateComponents([.day], from: item.createdAt, to: Date()).day ?? 0
        return max(1, days)
    }
    
    var viewsPerDayValue: Double {
        Double(item.viewCount) / Double(daysListed)
    }
    
    var viewsPerDay: String {
        String(format: "%.1f", viewsPerDayValue)
    }
    
    var saveRateValue: Double {
        guard item.viewCount > 0 else { return 0 }
        return (Double(item.savedCount) / Double(item.viewCount)) * 100
    }
    
    var saveRate: String {
        String(format: "%.1f%%", saveRateValue)
    }
    
    var engagementRate: String {
        guard item.viewCount > 0 else { return "0%" }
        let rate = (Double(item.savedCount) / Double(item.viewCount)) * 100
        return String(format: "%.0f%%", rate)
    }
    
    var performanceRating: String {
        let score = (viewsPerDayValue * 2) + saveRateValue
        
        if score >= 30 {
            return "Excellent"
        } else if score >= 20 {
            return "Good"
        } else if score >= 10 {
            return "Average"
        } else {
            return "Needs Improvement"
        }
    }
    
    var performanceColor: Color {
        let score = (viewsPerDayValue * 2) + saveRateValue
        
        if score >= 30 {
            return AppColors.success
        } else if score >= 20 {
            return AppColors.info
        } else if score >= 10 {
            return AppColors.warning
        } else {
            return AppColors.error
        }
    }
    
    // MARK: - ✅ NEW: Send Direct Message Function
    
    func sendDirectMessage() {
        guard let currentUser = Auth.auth().currentUser,
              let currentUserName = currentUser.displayName,
              let currentUserEmail = currentUser.email else {
            alertMessage = "Please login to send messages"
            showingAlert = true
            return
        }
        
        // Check if trying to message yourself
        if currentUser.uid == item.sellerId {
            alertMessage = "You cannot message yourself about your own item"
            showingAlert = true
            return
        }
        
        isSendingMessage = true
        
        messagingViewModel.createOrGetConversation(
            item: item,
            currentUserId: currentUser.uid,
            currentUserName: currentUserName,
            currentUserEmail: currentUserEmail
        ) { result in
            DispatchQueue.main.async {
                isSendingMessage = false
                
                switch result {
                case .success(let conversation):
                    print("✅ Conversation ready and message sent: \(conversation.id ?? "unknown")")
                    
                    // ✅ Show success state - button turns green with checkmark
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        messageSent = true
                    }
                    
                    // ✅ Provide haptic feedback
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.success)
                    
                case .failure(let error):
                    print("❌ Failed to create conversation: \(error.localizedDescription)")
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    func deleteItem() {
        marketplaceViewModel.deleteItem(item) { success, message in
            alertMessage = message
            showingAlert = true
        }
    }
    
    func markAsSold() {
        marketplaceViewModel.markAsSold(item) { success, message in
            alertMessage = message
            showingAlert = true
        }
    }
    
    func updateStatusToActive() {
        guard let itemId = item.id,
              item.listingStatus == "under_review" else {
            return
        }
        
        let db = Firestore.firestore()
        
        db.collection("marketplace_items").document(itemId).updateData([
            "listingStatus": "active",
            "statusUpdatedAt": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("❌ Failed to update status: \(error.localizedDescription)")
            } else {
                print("✅ Listing status updated to active")
            }
        }
    }
    
    func shareListing() {
        let text = """
        Check out this listing: \(item.title)
        
        💰 Price: \(item.formattedPrice)
        📍 Location: \(item.location)
        
        Condition: \(item.condition.rawValue)
        Category: \(item.category.rawValue)
        
        \(item.description)
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
    
    func relistItem() {
        guard let itemId = item.id else { return }
        
        marketplaceViewModel.updateItem(MarketplaceItem(
            id: itemId,
            title: item.title,
            description: item.description,
            price: item.price,
            category: item.category,
            condition: item.condition,
            location: item.location,
            city: item.city,
            latitude: item.latitude,
            longitude: item.longitude,
            sellerId: item.sellerId,
            sellerName: item.sellerName,
            sellerEmail: item.sellerEmail,
            photoURLs: item.photoURLs,
            isSold: false,
            viewCount: item.viewCount,
            savedCount: item.savedCount,
            createdAt: item.createdAt
        )) { success, message in
            alertMessage = message
            showingAlert = true
        }
    }
}

// MARK: - Supporting Components

struct MarketplaceStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    var isWide: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(AppFonts.title2)
                .foregroundColor(AppColors.textPrimary)
            
            Text(label)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
    }
}

struct InsightRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 32)
            
            Text(title)
                .font(AppFonts.callout)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(AppFonts.callout)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

struct TipRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(AppColors.success)
            
            Text(text)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
        }
    }
}
