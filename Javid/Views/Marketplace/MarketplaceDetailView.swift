import SwiftUI
import MapKit
import FirebaseAuth

struct MarketplaceDetailView: View {
    let item: MarketplaceItem
    @ObservedObject var marketplaceViewModel: MarketplaceViewModel
    
    @State private var region: MKCoordinateRegion
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingMarkSoldAlert = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingContactSheet = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var isOwner: Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return false
        }
        return item.sellerId == currentUserId
    }
    
    // Check if this item is saved
    var isSaved: Bool {
        guard let itemId = item.id else { return false }
        return marketplaceViewModel.isSaved(itemId: itemId)
    }
    
    init(item: MarketplaceItem, marketplaceViewModel: MarketplaceViewModel) {
        self.item = item
        self.marketplaceViewModel = marketplaceViewModel
        _region = State(initialValue: MKCoordinateRegion(
            center: item.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Image
                    HeroImageHeader(photoURLs: item.photoURLs)
                    
                    VStack(spacing: AppSpacing.lg) {
                        // Header Info
                        headerSection
                        
                        // Action Buttons
                        if !isOwner {
                            actionButtonsSection
                        } else {
                            ownerActionsSection
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
                        
                        // Seller Info Section
                        sellerSection
                        
                        Divider()
                            .padding(.horizontal, AppSpacing.md)
                        
                        // Location Section
                        locationSection
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
        .sheet(isPresented: $showingEditSheet) {
            EditMarketplaceItemView(item: item, marketplaceViewModel: marketplaceViewModel)
        }
        .sheet(isPresented: $showingContactSheet) {
            ContactSellerView(item: item)
        }
        .alert("Delete Item", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("Are you sure you want to delete '\(item.title)'? This action cannot be undone.")
        }
        .alert("Mark as Sold", isPresented: $showingMarkSoldAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Mark as Sold") {
                markAsSold()
            }
        } message: {
            Text("Mark '\(item.title)' as sold?")
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
        .onAppear {
            // Increment view count
            if let itemId = item.id {
                marketplaceViewModel.incrementViewCount(for: itemId)
            }
        }
    }
    
    // MARK: - Header Section
    
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    // Category Badge
                    HStack(spacing: 6) {
                        Image(systemName: item.category.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(item.category.rawValue)
                            .font(AppFonts.captionBold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: item.category.color))
                    .cornerRadius(AppRadius.sm)
                    
                    // Item Title
                    Text(item.title)
                        .font(AppFonts.title1)
                        .foregroundColor(AppColors.textPrimary)
                    
                    // Price
                    Text(item.formattedPrice)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppColors.primary)
                    
                    // Condition & Stats
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.success)
                            Text(item.condition.rawValue)
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Text("•")
                            .foregroundColor(AppColors.textTertiary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textSecondary)
                            Text("\(item.viewCount) views")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        if item.savedCount > 0 {
                            Text("•")
                                .foregroundColor(AppColors.textTertiary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.error)
                                Text("\(item.savedCount) saved")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Owner Menu
                if isOwner {
                    Menu {
                        Button(action: {
                            showingEditSheet = true
                        }) {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        if !item.isSold {
                            Button(action: {
                                showingMarkSoldAlert = true
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
            
            // Sold Banner
            if item.isSold {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                    Text("This item has been sold")
                        .font(AppFonts.bodyBold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(AppRadius.md)
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - Action Buttons Section
    
    var actionButtonsSection: some View {
        HStack(spacing: AppSpacing.md) {
            // Contact Seller Button
            Button(action: {
                showingContactSheet = true
            }) {
                HStack {
                    Image(systemName: "message.fill")
                    Text("Contact Seller")
                }
                .font(AppFonts.bodyBold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(item.isSold ? AppColors.textTertiary : AppColors.primary)
                .cornerRadius(AppRadius.md)
            }
            .disabled(item.isSold)
            
            // Save Button
            Button(action: {
                toggleSave()
            }) {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSaved ? AppColors.error : AppColors.textPrimary)
                    .frame(width: 56, height: 56)
                    .background(AppColors.surface)
                    .cornerRadius(AppRadius.md)
                    .shadow(color: AppShadow.small, radius: 4, x: 0, y: 2)
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - Owner Actions Section
    
    var ownerActionsSection: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Button(action: {
                    showingEditSheet = true
                }) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit Listing")
                    }
                    .font(AppFonts.bodyBold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.primary)
                    .cornerRadius(AppRadius.md)
                }
                
                if !item.isSold {
                    Button(action: {
                        showingMarkSoldAlert = true
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Mark Sold")
                        }
                        .font(AppFonts.bodyBold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.success)
                        .cornerRadius(AppRadius.md)
                    }
                }
            }
            
            Text("This is your listing")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - Description Section
    
    var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Description", icon: "doc.text.fill")
            
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
                DetailRow(
                    icon: "tag.fill",
                    title: "Category",
                    value: item.category.rawValue,
                    color: Color(hex: item.category.color)
                )
                
                DetailRow(
                    icon: "checkmark.seal.fill",
                    title: "Condition",
                    value: item.condition.rawValue,
                    color: AppColors.success
                )
                
                DetailRow(
                    icon: "calendar",
                    title: "Listed",
                    value: item.createdAt.timeAgo(),
                    color: AppColors.primary
                )
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Seller Section
    
    var sellerSection: some View {
        VStack(spacing: AppSpacing.sm) {
            SectionHeader(title: "Seller Information", icon: "person.fill")
            
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
                    
                    Text(item.sellerEmail)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .cornerRadius(AppRadius.md)
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
                    MapMarker(coordinate: item.coordinate, tint: .red)
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
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                }
            }
            .padding(.horizontal, AppSpacing.md)
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
    
    func toggleSave() {
        guard let itemId = item.id else {
            print("❌ Item ID missing")
            return
        }
        
        guard Auth.auth().currentUser != nil else {
            print("⚠️ User not logged in")
            alertMessage = "Please login to save items"
            showingAlert = true
            return
        }
        
        marketplaceViewModel.toggleSave(itemId: itemId) { success, message in
            if !success {
                self.alertMessage = message
                self.showingAlert = true
            }
        }
    }
}

// MARK: - Detail Row Component

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                
                Text(value)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
    }
}

// MARK: - Contact Seller View

struct ContactSellerView: View {
    let item: MarketplaceItem
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.lg) {
                // Seller Info
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppColors.primary.opacity(0.15))
                            .frame(width: 80, height: 80)
                        
                        Text(item.sellerName.prefix(1).uppercased())
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppColors.primary)
                    }
                    
                    Text(item.sellerName)
                        .font(AppFonts.title2)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(item.sellerEmail)
                        .font(AppFonts.callout)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, AppSpacing.xl)
                
                // Contact Options
                VStack(spacing: AppSpacing.md) {
                    Button(action: {
                        sendEmail()
                    }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 20))
                            Text("Send Email")
                                .font(AppFonts.bodyBold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.primary)
                        .cornerRadius(AppRadius.md)
                    }
                    
                    // Copy Email Button
                    Button(action: {
                        copyEmail()
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 20))
                            Text("Copy Email")
                                .font(AppFonts.bodyBold)
                        }
                        .foregroundColor(AppColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.primary.opacity(0.1))
                        .cornerRadius(AppRadius.md)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                
                // Item Info
                HStack(spacing: 12) {
                    if let firstPhotoURL = item.photoURLs.first,
                       let url = URL(string: firstPhotoURL) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipped()
                                .cornerRadius(AppRadius.md)
                        } placeholder: {
                            ZStack {
                                AppColors.surface
                                ProgressView()
                            }
                            .frame(width: 60, height: 60)
                            .cornerRadius(AppRadius.md)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(AppFonts.bodyBold)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                        
                        Text(item.formattedPrice)
                            .font(AppFonts.title3)
                            .foregroundColor(AppColors.primary)
                    }
                    
                    Spacer()
                }
                .padding(AppSpacing.md)
                .background(AppColors.surface)
                .cornerRadius(AppRadius.md)
                .padding(.horizontal, AppSpacing.lg)
                
                Spacer()
            }
            .background(AppColors.background)
            .navigationTitle("Contact Seller")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    func sendEmail() {
        let subject = "Interested in: \(item.title)"
        let body = "Hi \(item.sellerName),\n\nI'm interested in your item '\(item.title)' listed for \(item.formattedPrice).\n\n"
        
        if let url = URL(string: "mailto:\(item.sellerEmail)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        }
    }
    
    func copyEmail() {
        UIPasteboard.general.string = item.sellerEmail
    }
}
