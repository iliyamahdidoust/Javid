import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var businessViewModel: BusinessViewModel
    @EnvironmentObject var favoriteViewModel: FavoriteViewModel
    
    @State private var showingAddBusiness = false
    @State private var showingLoginSheet = false
    @State private var selectedTab = 0 // 0: My Businesses, 1: Favorites
    
    var userBusinesses: [Business] {
        businessViewModel.getUserBusinesses()
    }
    
    var favoriteBusinesses: [Business] {
        favoriteViewModel.getFavoriteBusinesses(from: businessViewModel.businesses)
    }
    
    var isBusinessOwner: Bool {
        authViewModel.userProfile?.isBusinessOwner ?? false
    }
    
    var body: some View {
        NavigationView {
            if authViewModel.isLoggedIn {
                // Logged In View
                VStack(spacing: 0) {
                    // Account Section
                    accountSection
                    
                    // Tab Selector - Always show for logged in users
                    tabSelector
                    
                    // Content based on selected tab
                    if selectedTab == 0 && isBusinessOwner {
                        myBusinessesContent
                    } else {
                        favoritesContent
                    }
                }
                .navigationTitle("Profile")
                .sheet(isPresented: $showingAddBusiness) {
                    AddBusinessView(businessViewModel: businessViewModel)
                }
            } else {
                // Not Logged In View
                notLoggedInView
            }
        }
    }
    
    // MARK: - Account Section
    
    var accountSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(AppColors.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(authViewModel.currentUser?.displayName ?? "User")
                        .font(AppFonts.title3)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(authViewModel.currentUser?.email ?? "")
                        .font(AppFonts.callout)
                        .foregroundColor(AppColors.textSecondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: isBusinessOwner ? "briefcase.fill" : "person.fill")
                            .font(.caption)
                        Text(isBusinessOwner ? "Business Owner" : "Regular User")
                            .font(AppFonts.caption)
                    }
                    .foregroundColor(isBusinessOwner ? AppColors.primary : AppColors.textSecondary)
                    .padding(.top, 4)
                }
                .padding(.leading, 12)
                
                Spacer()
                
                // Logout Button
                Button(action: {
                    authViewModel.signOut()
                }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.error)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            
            Divider()
        }
    }
    
    // MARK: - Tab Selector
    
    var tabSelector: some View {
        HStack(spacing: 0) {
            // My Businesses Tab (only for business owners)
            if isBusinessOwner {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = 0
                    }
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "building.2")
                                .font(.system(size: 16, weight: .semibold))
                            Text("My Businesses")
                                .font(AppFonts.callout)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(selectedTab == 0 ? AppColors.primary : AppColors.textSecondary)
                        
                        Rectangle()
                            .fill(selectedTab == 0 ? AppColors.primary : Color.clear)
                            .frame(height: 3)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            // Favorites Tab
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = 1
                }
            }) {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Favorites")
                            .font(AppFonts.callout)
                            .fontWeight(.semibold)
                        
                        // Show count badge
                        if !favoriteBusinesses.isEmpty {
                            Text("\(favoriteBusinesses.count)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.primary)
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundColor(selectedTab == 1 ? AppColors.primary : AppColors.textSecondary)
                    
                    Rectangle()
                        .fill(selectedTab == 1 ? AppColors.primary : Color.clear)
                        .frame(height: 3)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, AppSpacing.sm)
        .background(AppColors.surface)
    }
    
    // MARK: - My Businesses Content
    
    var myBusinessesContent: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                if userBusinesses.isEmpty {
                    // Empty State
                    VStack(spacing: AppSpacing.lg) {
                        Spacer()
                        
                        Image(systemName: "building.2.crop.circle")
                            .font(.system(size: 80))
                            .foregroundColor(AppColors.textTertiary)
                        
                        VStack(spacing: 8) {
                            Text("No businesses yet")
                                .font(AppFonts.title2)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("Start by adding your first business")
                                .font(AppFonts.callout)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Button(action: {
                            showingAddBusiness = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Business")
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
                    .padding()
                } else {
                    // Business List
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(userBusinesses) { business in
                            NavigationLink(destination: BusinessDetailView(business: business)) {
                                BusinessListCard(business: business)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(AppSpacing.md)
                    
                    // Add Business Button
                    Button(action: {
                        showingAddBusiness = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add New Business")
                        }
                        .font(AppFonts.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.primary.opacity(0.1))
                        .cornerRadius(AppRadius.md)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.md)
                }
            }
        }
        .background(AppColors.background)
    }
    
    // MARK: - Favorites Content
    
    var favoritesContent: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                if favoriteBusinesses.isEmpty {
                    // Empty State
                    VStack(spacing: AppSpacing.lg) {
                        Spacer()
                        
                        Image(systemName: "heart.circle")
                            .font(.system(size: 80))
                            .foregroundColor(AppColors.textTertiary)
                        
                        VStack(spacing: 8) {
                            Text("No favorites yet")
                                .font(AppFonts.title2)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("Save businesses you love to find them easily")
                                .font(AppFonts.callout)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, AppSpacing.xl)
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    // Favorites List
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(favoriteBusinesses) { business in
                            NavigationLink(destination: BusinessDetailView(business: business)) {
                                FavoriteBusinessCard(business: business)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(AppSpacing.md)
                }
            }
        }
        .background(AppColors.background)
        .onAppear {
            // Refresh favorites when view appears
            favoriteViewModel.fetchUserFavorites()
        }
    }
    
    // MARK: - Not Logged In View
    
    var notLoggedInView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "person.circle")
                .font(.system(size: 80))
                .foregroundColor(AppColors.primary)
            
            VStack(spacing: 12) {
                Text("Sign in to access your profile")
                    .font(AppFonts.title2)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Create an account to add businesses, write reviews, and save your favorites")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: {
                showingLoginSheet = true
            }) {
                Text("Sign In / Sign Up")
                    .font(AppFonts.bodyBold)
                    .foregroundColor(.white)
                    .frame(maxWidth: 250)
                    .padding()
                    .background(AppColors.primary)
                    .cornerRadius(AppRadius.md)
            }
            
            Spacer()
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $showingLoginSheet) {
            AuthView(authViewModel: authViewModel)
        }
    }
    
    // MARK: - Business List Card
    
    struct BusinessListCard: View {
        let business: Business
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            HStack(spacing: 12) {
                // Business Image
                if let firstPhotoURL = business.photoURLs.first,
                   let url = URL(string: firstPhotoURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipped()
                            .cornerRadius(AppRadius.md)
                    } placeholder: {
                        ZStack {
                            AppColors.surface
                            ProgressView()
                        }
                        .frame(width: 80, height: 80)
                        .cornerRadius(AppRadius.md)
                    }
                } else {
                    ZStack {
                        AppColors.surface
                        Image(systemName: "building.2")
                            .font(.system(size: 30))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .frame(width: 80, height: 80)
                    .cornerRadius(AppRadius.md)
                }
                
                // Business Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(business.name)
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    Text(business.category)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.categoryColor(for: business.category).opacity(0.15))
                        .cornerRadius(AppRadius.sm)
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.starYellow)
                            Text(String(format: "%.1f", business.rating))
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Text("•")
                            .foregroundColor(AppColors.textTertiary)
                            .font(.caption)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.primary)
                            Text(business.city)
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .cornerRadius(AppRadius.md)
            .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.small, radius: 4, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(colorScheme == .dark ? AppColors.border.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Favorite Business Card
    
    struct FavoriteBusinessCard: View {
        let business: Business
        @EnvironmentObject var favoriteViewModel: FavoriteViewModel
        @State private var isRemoving = false
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            HStack(spacing: 12) {
                // Business Image
                if let firstPhotoURL = business.photoURLs.first,
                   let url = URL(string: firstPhotoURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipped()
                            .cornerRadius(AppRadius.md)
                    } placeholder: {
                        ZStack {
                            AppColors.surface
                            ProgressView()
                        }
                        .frame(width: 80, height: 80)
                        .cornerRadius(AppRadius.md)
                    }
                } else {
                    ZStack {
                        AppColors.surface
                        Image(systemName: "building.2")
                            .font(.system(size: 30))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .frame(width: 80, height: 80)
                    .cornerRadius(AppRadius.md)
                }
                
                // Business Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(business.name)
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    Text(business.category)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.categoryColor(for: business.category).opacity(0.15))
                        .cornerRadius(AppRadius.sm)
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.starYellow)
                            Text(String(format: "%.1f", business.rating))
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Text("•")
                            .foregroundColor(AppColors.textTertiary)
                            .font(.caption)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.primary)
                            Text(business.city)
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                // Remove from favorites button
                Button(action: {
                    removeFavorite()
                }) {
                    if isRemoving {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.error)
                    }
                }
                .disabled(isRemoving)
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .cornerRadius(AppRadius.md)
            .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.small, radius: 4, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(colorScheme == .dark ? AppColors.border.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        
        func removeFavorite() {
            guard let businessId = business.id else { return }
            isRemoving = true
            
            favoriteViewModel.removeFavorite(businessId: businessId) { success, message in
                isRemoving = false
                print(message)
            }
        }
    }
}
