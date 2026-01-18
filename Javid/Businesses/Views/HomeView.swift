import SwiftUI
import CoreLocation

struct HomeView: View {
    @ObservedObject var businessViewModel: BusinessViewModel
    @EnvironmentObject var favoriteViewModel: FavoriteViewModel  // ✅ Added this
    @StateObject private var locationManager = LocationManager()
    @State private var selectedCategory = "All"
    @State private var isRefreshing = false
    @State private var showingLocationPermission = false
    @State private var isLocationLoading = false
    
    @Environment(\.colorScheme) var colorScheme
    
    let categories = ["All", "Restaurant", "Store", "Services", "Doctor", "Lawyer", "Salon"]
    
    var filteredBusinesses: [Business] {
        businessViewModel.businesses.filter { business in
            let matchesCategory = selectedCategory == "All" || business.category == selectedCategory
            return matchesCategory
        }
    }
    
    var sortedBusinesses: [Business] {
        if businessViewModel.sortByDistance, let userLocation = locationManager.location {
            return filteredBusinesses.sorted { business1, business2 in
                let distance1 = userLocation.distance(from: CLLocation(
                    latitude: business1.latitude,
                    longitude: business1.longitude
                ))
                let distance2 = userLocation.distance(from: CLLocation(
                    latitude: business2.latitude,
                    longitude: business2.longitude
                ))
                return distance1 < distance2
            }
        } else {
            return filteredBusinesses
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Section
                    VStack(spacing: AppSpacing.md) {
                        // Categories
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(categories, id: \.self) { category in
                                    CategoryChip(
                                        title: category,
                                        isSelected: selectedCategory == category,
                                        icon: categoryIcon(for: category)
                                    ) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedCategory = category
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                        }
                        .padding(.top, AppSpacing.md)
                        
                        // Near Me Button
                        nearMeSection
                    }
                    .padding(.bottom, AppSpacing.md)
                    .background(AppColors.surface)
                    
                    // Business List
                    if businessViewModel.isLoading && businessViewModel.businesses.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: AppSpacing.md) {
                                ForEach(0..<4, id: \.self) { _ in
                                    SkeletonBusinessCard()
                                }
                            }
                            .padding(AppSpacing.md)
                        }
                    } else if sortedBusinesses.isEmpty {
                        VStack(spacing: AppSpacing.lg) {
                            Spacer()
                            
                            Image(systemName: "building.2.crop.circle")
                                .font(.system(size: 80))
                                .foregroundColor(AppColors.textTertiary)
                            
                            VStack(spacing: 8) {
                                Text("No businesses found")
                                    .font(AppFonts.title2)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                if selectedCategory != "All" {
                                    Text("Try selecting a different category")
                                        .font(AppFonts.callout)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }
                            
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: AppSpacing.md) {
                                // Refresh indicator
                                if isRefreshing {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                        Text("Refreshing...")
                                            .font(AppFonts.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                        Spacer()
                                    }
                                    .padding(.vertical, AppSpacing.sm)
                                }
                                
                                // Business Cards
                                ForEach(Array(sortedBusinesses.enumerated()), id: \.element.id) { index, business in
                                    NavigationLink(destination: BusinessDetailView(business: business)) {
                                        ModernBusinessCard(
                                            business: business,
                                            distance: locationManager.location != nil ? businessViewModel.getDistance(to: business) : nil
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .onAppear {
                                        if index == sortedBusinesses.count - 3 {
                                            businessViewModel.loadMoreBusinesses()
                                        }
                                    }
                                }
                                
                                // Loading more indicator
                                if businessViewModel.isLoadingMore {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                        Text("Loading more...")
                                            .font(AppFonts.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                        Spacer()
                                    }
                                    .padding(.vertical, AppSpacing.md)
                                }
                                
                                // End message
                                if !businessViewModel.hasMoreData && !businessViewModel.businesses.isEmpty {
                                    Text("You've reached the end")
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.textTertiary)
                                        .padding(.vertical, AppSpacing.lg)
                                }
                            }
                            .padding(AppSpacing.md)
                        }
                        .refreshable {
                            await refreshData()
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("Location Permission", isPresented: $showingLocationPermission) {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable location access in Settings to use the Near Me feature.")
            }
            .onAppear {
                requestLocationIfNeeded()
            }
            .onChange(of: locationManager.authorizationStatus) { newStatus in
                handleAuthorizationChange(newStatus)
            }
            .onChange(of: locationManager.location) { newLocation in
                if let location = newLocation {
                    if businessViewModel.sortByDistance {
                        businessViewModel.sortBusinessesByDistance(userLocation: location)
                    }
                }
            }
        }
    }
    
    // MARK: - Near Me Section
    
    var nearMeSection: some View {
        VStack(spacing: AppSpacing.sm) {
            if locationManager.authorizationStatus == .authorizedWhenInUse ||
               locationManager.authorizationStatus == .authorizedAlways {
                HStack(spacing: AppSpacing.sm) {
                    Button(action: {
                        toggleNearMe()
                    }) {
                        HStack(spacing: 8) {
                            if isLocationLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: businessViewModel.sortByDistance ? "location.fill" : "location")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            
                            Text(businessViewModel.sortByDistance ? "Showing Nearest" : "Near Me")
                                .font(AppFonts.callout)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(businessViewModel.sortByDistance ? .white : AppColors.primary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 10)
                        .background(businessViewModel.sortByDistance ? AppColors.primary : AppColors.surface)
                        .cornerRadius(AppRadius.full)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.full)
                                .stroke(businessViewModel.sortByDistance ? Color.clear : AppColors.border, lineWidth: 1.5)
                        )
                        .shadow(color: businessViewModel.sortByDistance ? AppColors.primary.opacity(0.3) : Color.clear, radius: businessViewModel.sortByDistance ? 6 : 2, x: 0, y: businessViewModel.sortByDistance ? 3 : 1)
                    }
                    .disabled(isLocationLoading)
                    
                    if businessViewModel.sortByDistance, let location = locationManager.location {
                        HStack(spacing: 4) {
                            Image(systemName: "location.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.primary)
                            Text(String(format: "%.2f, %.2f", location.coordinate.latitude, location.coordinate.longitude))
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppColors.surface)
                        .cornerRadius(AppRadius.full)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.full)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)
            } else if locationManager.authorizationStatus == .notDetermined {
                Button(action: {
                    locationManager.requestPermission()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "location")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Enable Near Me")
                            .font(AppFonts.callout)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 10)
                    .background(AppColors.primary.opacity(0.1))
                    .cornerRadius(AppRadius.full)
                }
                .padding(.horizontal, AppSpacing.md)
            } else {
                Button(action: {
                    showingLocationPermission = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Location Disabled - Tap to Enable")
                            .font(AppFonts.callout)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(AppColors.warning)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 10)
                    .background(AppColors.warning.opacity(0.1))
                    .cornerRadius(AppRadius.full)
                }
                .padding(.horizontal, AppSpacing.md)
            }
            
            // Error Message
            if let error = locationManager.locationError {
                Text(error)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.error)
                    .padding(.horizontal, AppSpacing.md)
            }
        }
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
    
    func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdating()
        case .denied, .restricted:
            businessViewModel.sortByDistance = false
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
    
    @MainActor
    func refreshData() async {
        isRefreshing = true
        businessViewModel.refreshBusinesses()
        
        while businessViewModel.isLoading {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        isRefreshing = false
    }
    
    func toggleNearMe() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            showingLocationPermission = true
            return
        }
        
        if businessViewModel.sortByDistance {
            businessViewModel.sortByDistance = false
        } else {
            if let location = locationManager.location {
                businessViewModel.sortByDistance = true
                businessViewModel.sortBusinessesByDistance(userLocation: location)
            } else {
                isLocationLoading = true
                locationManager.startUpdating()
                
                Task {
                    var attempts = 0
                    while locationManager.location == nil && attempts < 20 {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        attempts += 1
                    }
                    
                    await MainActor.run {
                        isLocationLoading = false
                        
                        if let location = locationManager.location {
                            businessViewModel.sortByDistance = true
                            businessViewModel.sortBusinessesByDistance(userLocation: location)
                        } else {
                            showingLocationPermission = true
                        }
                    }
                }
            }
        }
    }
    
    func categoryIcon(for category: String) -> String? {
        switch category {
        case "All": return "square.grid.2x2"
        case "Restaurant": return "fork.knife"
        case "Store": return "cart"
        case "Services": return "wrench.and.screwdriver"
        case "Doctor": return "cross.case"
        case "Lawyer": return "briefcase"
        case "Salon": return "scissors"
        default: return nil
        }
    }
}

// MARK: - Skeleton Loading Card
struct SkeletonBusinessCard: View {
    @State private var isAnimating = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(AppColors.surface.opacity(0.5))
                .frame(height: 180)
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
            
            VStack(alignment: .leading, spacing: 12) {
                Rectangle()
                    .fill(AppColors.surface.opacity(0.5))
                    .frame(width: 200, height: 20)
                    .cornerRadius(4)
                
                VStack(spacing: 6) {
                    Rectangle()
                        .fill(AppColors.surface.opacity(0.5))
                        .frame(height: 14)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(AppColors.surface.opacity(0.5))
                        .frame(width: 250, height: 14)
                        .cornerRadius(4)
                }
                
                Rectangle()
                    .fill(AppColors.surface.opacity(0.5))
                    .frame(width: 150, height: 12)
                    .cornerRadius(4)
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
        }
        .background(AppColors.surface)
        .cornerRadius(AppRadius.lg)
        .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.small, radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(colorScheme == .dark ? AppColors.border.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .onAppear {
            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}
