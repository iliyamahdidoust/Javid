import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    // MARK: - Properties
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var businessViewModel: BusinessViewModel
    @EnvironmentObject var favoriteViewModel: FavoriteViewModel
    
    @State private var showingAddBusiness = false
    @State private var showingLoginSheet = false
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var selectedTab = 0
    @State private var isRefreshing = false
    @State private var showingBecomeOwnerAlert = false
    
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Computed Properties
    
    var userBusinesses: [Business] {
        businessViewModel.getUserBusinesses()
    }
    
    var favoriteBusinesses: [Business] {
        favoriteViewModel.getFavoriteBusinesses(from: businessViewModel.businesses)
    }
    
    var isBusinessOwner: Bool {
        authViewModel.userProfile?.isBusinessOwner ?? false
    }
    
    var userDisplayName: String {
        authViewModel.userProfile?.name ??
        authViewModel.currentUser?.displayName ??
        "User"
    }
    
    var userEmail: String {
        authViewModel.userProfile?.email ??
        authViewModel.currentUser?.email ??
        ""
    }
    
    var userProfileImageURL: String? {
        authViewModel.userProfile?.profileImageURL
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            if authViewModel.isLoggedIn {
                loggedInView
            } else {
                notLoggedInView
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Actions
    
    @MainActor
    private func refreshData() async {
        isRefreshing = true
        
        // Refresh user profile
        await authViewModel.refreshUserProfile()
        
        // Refresh businesses
        businessViewModel.fetchBusinesses()
        
        // Refresh favorites - call the method directly on the ViewModel
        favoriteViewModel.fetchUserFavorites()
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        isRefreshing = false
    }
    
    private func becomeBusinessOwner() {
        Task {
            await authViewModel.upgradeToBusinessOwner { success, message in
                print(success ? "✅ \(message)" : "❌ \(message)")
            }
        }
    }
}

// MARK: - EXTENSION: Views
extension ProfileView {
    
    // MARK: - Logged In View
    
    var loggedInView: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                enhancedAccountSection
                adaptiveTabSelector
                
                TabView(selection: $selectedTab) {
                    if isBusinessOwner {
                        myBusinessesContent.tag(0)
                    }
                    favoritesContent.tag(isBusinessOwner ? 1 : 0)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: selectedTab)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if !isBusinessOwner {
                            Button {
                                showingBecomeOwnerAlert = true
                            } label: {
                                Label("Become Business Owner", systemImage: "briefcase.fill")
                            }
                        }
                        
                        Button { showingEditProfile = true } label: {
                            Label("Edit Profile", systemImage: "pencil")
                        }
                        
                        Button { showingSettings = true } label: {
                            Label("Settings", systemImage: "gear")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            authViewModel.signOut()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
        }
        .refreshable { await refreshData() }
        .sheet(isPresented: $showingAddBusiness) {
            AddBusinessView(businessViewModel: businessViewModel)
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView(authViewModel: authViewModel)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(authViewModel: authViewModel)
        }
        .alert("Become a Business Owner", isPresented: $showingBecomeOwnerAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Continue") { becomeBusinessOwner() }
        } message: {
            Text("Would you like to upgrade your account to a Business Owner? This will allow you to add and manage your businesses.")
        }
    }
    
    // MARK: - Enhanced Account Section
    
    var enhancedAccountSection: some View {
        VStack(spacing: 0) {
            VStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.md) {
                    profileImageView
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(userDisplayName)
                            .font(AppFonts.title3)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                        
                        Text(userEmail)
                            .font(AppFonts.callout)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                        
                        HStack(spacing: 6) {
                            Image(systemName: isBusinessOwner ? "briefcase.fill" : "person.fill")
                                .font(.system(size: 12))
                            Text(isBusinessOwner ? "Business Owner" : "Member")
                                .font(AppFonts.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: isBusinessOwner ?
                                    [AppColors.primary, AppColors.primary.opacity(0.8)] :
                                    [AppColors.textSecondary, AppColors.textSecondary.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(AppRadius.sm)
                    }
                    Spacer()
                }
                statsRow
            }
            .padding(AppSpacing.md)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [AppColors.surface, AppColors.surface.opacity(0.95)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            Divider()
        }
    }
    
    var profileImageView: some View {
        Group {
            if let profileImageURL = userProfileImageURL, let url = URL(string: profileImageURL) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill().frame(width: 70, height: 70).clipShape(Circle())
                        .overlay(Circle().stroke(AppColors.primary, lineWidth: 3))
                } placeholder: {
                    profilePlaceholder
                }
            } else {
                profilePlaceholder
            }
        }
        .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    var profilePlaceholder: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(gradient: Gradient(colors: [AppColors.primary.opacity(0.8), AppColors.primary]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 70, height: 70)
            Text(String(userDisplayName.prefix(1)).uppercased())
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
        }
        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
    }
    
    var statsRow: some View {
        HStack(spacing: 0) {
            if isBusinessOwner {
                statItem(value: "\(userBusinesses.count)", label: "Businesses", icon: "building.2")
                Divider().frame(height: 40).padding(.horizontal, AppSpacing.sm)
            }
            statItem(value: "\(favoriteBusinesses.count)", label: "Favorites", icon: "heart.fill")
            if isBusinessOwner {
                Divider().frame(height: 40).padding(.horizontal, AppSpacing.sm)
                statItem(value: calculateTotalReviews(), label: "Reviews", icon: "star.fill")
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .padding(.horizontal, AppSpacing.md)
        .background(RoundedRectangle(cornerRadius: AppRadius.md).fill(AppColors.background.opacity(0.5)))
    }
    
    func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.primary)
                Text(value).font(.system(size: 22, weight: .bold)).foregroundColor(AppColors.textPrimary)
            }
            Text(label).font(AppFonts.caption).foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    func calculateTotalReviews() -> String {
        let total = userBusinesses.reduce(0) { $0 + ($1.reviewCount ?? 0) }
        return total >= 1000 ? String(format: "%.1fk", Double(total) / 1000.0) : "\(total)"
    }
    
    // MARK: - Tab Selector
    
    var adaptiveTabSelector: some View {
        HStack(spacing: 0) {
            if isBusinessOwner {
                tabButton(title: "My Businesses", icon: "building.2", index: 0, count: userBusinesses.count)
            }
            tabButton(title: "Favorites", icon: "heart.fill", index: isBusinessOwner ? 1 : 0, count: favoriteBusinesses.count)
        }
        .padding(.top, AppSpacing.sm)
        .background(AppColors.surface)
    }
    
    func tabButton(title: String, icon: String, index: Int, count: Int) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
        }) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                    Text(title).font(AppFonts.callout).fontWeight(.semibold)
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(selectedTab == index ? AppColors.primary : AppColors.textTertiary))
                    }
                }
                .foregroundColor(selectedTab == index ? AppColors.primary : AppColors.textSecondary)
                .padding(.vertical, 10)
                Rectangle().fill(selectedTab == index ? AppColors.primary : Color.clear).frame(height: 3).cornerRadius(1.5)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - EXTENSION: Content Views
extension ProfileView {
    
    // MARK: - My Businesses Content
    
    var myBusinessesContent: some View {
        ZStack {
            if businessViewModel.isLoading && userBusinesses.isEmpty {
                loadingView
            } else if userBusinesses.isEmpty {
                emptyBusinessesState
            } else {
                businessesListView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var loadingView: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView().scaleEffect(1.5).tint(AppColors.primary)
            Text("Loading...").font(AppFonts.callout).foregroundColor(AppColors.textSecondary)
        }
    }
    
    var emptyBusinessesState: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                Spacer().frame(height: 60)
                ZStack {
                    Circle().fill(AppColors.primary.opacity(0.1)).frame(width: 140, height: 140)
                    Image(systemName: "building.2.crop.circle").font(.system(size: 70)).foregroundColor(AppColors.primary)
                }
                VStack(spacing: AppSpacing.sm) {
                    Text("Start Your Business Journey").font(AppFonts.title2).fontWeight(.bold)
                    Text("Add your first business and start connecting with customers").font(AppFonts.body).foregroundColor(AppColors.textSecondary).multilineTextAlignment(.center).padding(.horizontal, AppSpacing.xl)
                }
                Button(action: { showingAddBusiness = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 20))
                        Text("Add Your First Business").font(AppFonts.bodyBold)
                    }
                    .foregroundColor(.white).padding(.horizontal, AppSpacing.xl).padding(.vertical, AppSpacing.md)
                    .background(LinearGradient(gradient: Gradient(colors: [AppColors.primary, AppColors.primary.opacity(0.8)]), startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(AppRadius.lg).shadow(color: AppColors.primary.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(ProfileScaleButtonStyle())
                Spacer()
            }
        }
    }
    
    var businessesListView: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("My Businesses").font(AppFonts.title3).fontWeight(.bold)
                        Text("\(userBusinesses.count) \(userBusinesses.count == 1 ? "business" : "businesses")").font(AppFonts.caption).foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Button(action: { showingAddBusiness = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 14, weight: .semibold))
                            Text("Add").font(AppFonts.callout).fontWeight(.semibold)
                        }
                        .foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 10)
                        .background(AppColors.primary).cornerRadius(AppRadius.md)
                        .shadow(color: AppColors.primary.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .buttonStyle(ProfileScaleButtonStyle())
                }
                .padding(.horizontal, AppSpacing.md).padding(.top, AppSpacing.md)
                
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(userBusinesses) { business in
                        NavigationLink(destination: BusinessDetailView(business: business)) {
                            EnhancedBusinessCard(business: business)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, AppSpacing.md).padding(.bottom, AppSpacing.lg)
            }
        }
    }
    
    // MARK: - Favorites Content
    
    var favoritesContent: some View {
        ZStack {
            if favoriteViewModel.isLoading && favoriteBusinesses.isEmpty {
                loadingView
            } else if favoriteBusinesses.isEmpty {
                emptyFavoritesState
            } else {
                favoritesListView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var emptyFavoritesState: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                Spacer().frame(height: 60)
                ZStack {
                    Circle().fill(AppColors.error.opacity(0.1)).frame(width: 140, height: 140)
                    Image(systemName: "heart.circle").font(.system(size: 70)).foregroundColor(AppColors.error)
                }
                VStack(spacing: AppSpacing.sm) {
                    Text("No Favorites Yet").font(AppFonts.title2).fontWeight(.bold)
                    Text("Start exploring and save your favorite businesses here").font(AppFonts.body).foregroundColor(AppColors.textSecondary).multilineTextAlignment(.center).padding(.horizontal, AppSpacing.xl)
                }
                Spacer()
            }
        }
    }
    
    var favoritesListView: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("My Favorites").font(AppFonts.title3).fontWeight(.bold)
                        Text("\(favoriteBusinesses.count) \(favoriteBusinesses.count == 1 ? "favorite" : "favorites")").font(AppFonts.caption).foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md).padding(.top, AppSpacing.md)
                
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(favoriteBusinesses) { business in
                        NavigationLink(destination: BusinessDetailView(business: business)) {
                            EnhancedFavoriteCard(business: business)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, AppSpacing.md).padding(.bottom, AppSpacing.lg)
            }
        }
    }
    
    // MARK: - Not Logged In View
    
    var notLoggedInView: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [AppColors.primary.opacity(0.1), AppColors.background]), startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    Spacer().frame(height: 40)
                    ZStack {
                        Circle().fill(LinearGradient(gradient: Gradient(colors: [AppColors.primary.opacity(0.2), AppColors.primary.opacity(0.05)]), startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 160, height: 160)
                        Image(systemName: "person.circle.fill").font(.system(size: 90)).foregroundColor(AppColors.primary)
                    }
                    VStack(spacing: AppSpacing.md) {
                        Text("Welcome!").font(.system(size: 32, weight: .bold))
                        Text("Sign in to access your profile, manage businesses, and save your favorites").font(AppFonts.body).foregroundColor(AppColors.textSecondary).multilineTextAlignment(.center).padding(.horizontal, AppSpacing.xl)
                    }
                    Button(action: { showingLoginSheet = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.fill").font(.system(size: 18))
                            Text("Sign In").font(AppFonts.title3).fontWeight(.semibold)
                        }
                        .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(LinearGradient(gradient: Gradient(colors: [AppColors.primary, AppColors.primary.opacity(0.8)]), startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(AppRadius.lg).shadow(color: AppColors.primary.opacity(0.4), radius: 15, x: 0, y: 8)
                    }
                    .buttonStyle(ProfileScaleButtonStyle())
                    .padding(.horizontal, AppSpacing.xl)
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showingLoginSheet) {
            AuthView(authViewModel: authViewModel)
        }
    }
}

// MARK: - EXTENSION: Card Components
extension ProfileView {
    
    struct EnhancedBusinessCard: View {
        let business: Business
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            VStack(spacing: 0) {
                HStack(spacing: AppSpacing.md) {
                    businessImage
                    VStack(alignment: .leading, spacing: 6) {
                        Text(business.name).font(AppFonts.bodyBold).foregroundColor(AppColors.textPrimary).lineLimit(1)
                        Text(business.category).font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.categoryColor(for: business.category))
                            .padding(.horizontal, 8).padding(.vertical, 4).background(AppColors.categoryColor(for: business.category).opacity(0.15)).cornerRadius(AppRadius.sm)
                        HStack(spacing: 10) {
                            statBadge(icon: "star.fill", value: String(format: "%.1f", business.rating), color: AppColors.starYellow)
                            statBadge(icon: "text.bubble.fill", value: "\(business.reviewCount)", color: AppColors.primary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.surface).cornerRadius(AppRadius.md)
            .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.small, radius: 4, x: 0, y: 2)
            .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(colorScheme == .dark ? AppColors.border.opacity(0.2) : Color.clear, lineWidth: 1))
        }
        
        var businessImage: some View {
            Group {
                if let firstPhotoURL = business.photoURLs.first, let url = URL(string: firstPhotoURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill().frame(width: 90, height: 90).clipped().cornerRadius(AppRadius.md)
                    } placeholder: {
                        imagePlaceholder
                    }
                } else {
                    imagePlaceholder
                }
            }
        }
        
        var imagePlaceholder: some View {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [AppColors.surface, AppColors.background]), startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "building.2").font(.system(size: 35)).foregroundColor(AppColors.textTertiary)
            }
            .frame(width: 90, height: 90).cornerRadius(AppRadius.md)
        }
        
        func statBadge(icon: String, value: String, color: Color) -> some View {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 10)).foregroundColor(color)
                Text(value).font(.system(size: 11, weight: .medium)).foregroundColor(AppColors.textSecondary)
            }
        }
    }
    
    struct EnhancedFavoriteCard: View {
        let business: Business
        @EnvironmentObject var favoriteViewModel: FavoriteViewModel
        @State private var isRemoving = false
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            HStack(spacing: AppSpacing.md) {
                businessImage
                VStack(alignment: .leading, spacing: 6) {
                    Text(business.name).font(AppFonts.bodyBold).foregroundColor(AppColors.textPrimary).lineLimit(1)
                    Text(business.category).font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.categoryColor(for: business.category))
                        .padding(.horizontal, 8).padding(.vertical, 4).background(AppColors.categoryColor(for: business.category).opacity(0.15)).cornerRadius(AppRadius.sm)
                    HStack(spacing: 10) {
                        statBadge(icon: "star.fill", value: String(format: "%.1f", business.rating), color: AppColors.starYellow)
                        Text("•").foregroundColor(AppColors.textTertiary).font(.caption)
                        statBadge(icon: "location.fill", value: business.city, color: AppColors.primary)
                    }
                }
                Spacer()
                Button(action: removeFavorite) {
                    if isRemoving {
                        ProgressView().scaleEffect(0.8).frame(width: 40, height: 40)
                    } else {
                        ZStack {
                            Circle().fill(AppColors.error.opacity(0.1)).frame(width: 40, height: 40)
                            Image(systemName: "heart.fill").font(.system(size: 18)).foregroundColor(AppColors.error)
                        }
                    }
                }
                .disabled(isRemoving).buttonStyle(ProfileScaleButtonStyle())
            }
            .padding(AppSpacing.md).background(AppColors.surface).cornerRadius(AppRadius.md)
            .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.small, radius: 4, x: 0, y: 2)
            .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(colorScheme == .dark ? AppColors.border.opacity(0.2) : Color.clear, lineWidth: 1))
        }
        
        var businessImage: some View {
            Group {
                if let firstPhotoURL = business.photoURLs.first, let url = URL(string: firstPhotoURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill().frame(width: 90, height: 90).clipped().cornerRadius(AppRadius.md)
                    } placeholder: {
                        imagePlaceholder
                    }
                } else {
                    imagePlaceholder
                }
            }
        }
        
        var imagePlaceholder: some View {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [AppColors.surface, AppColors.background]), startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "building.2").font(.system(size: 35)).foregroundColor(AppColors.textTertiary)
            }
            .frame(width: 90, height: 90).cornerRadius(AppRadius.md)
        }
        
        func statBadge(icon: String, value: String, color: Color) -> some View {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 10)).foregroundColor(color)
                Text(value).font(.system(size: 11, weight: .medium)).foregroundColor(AppColors.textSecondary)
            }
        }
        
        func removeFavorite() {
            guard let businessId = business.id else { return }
            isRemoving = true
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            favoriteViewModel.removeFavorite(businessId: businessId) { success, message in
                isRemoving = false
                if success {
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                }
            }
        }
    }
    
    // MARK: - Supporting Components
    struct ProfileScaleButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
        }
    }
}
