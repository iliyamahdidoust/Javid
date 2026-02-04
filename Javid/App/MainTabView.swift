import SwiftUI

struct MainTabView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var businessViewModel = BusinessViewModel()
    @StateObject private var favoriteViewModel = FavoriteViewModel()
    @State private var showingAdminPanel = false
    
    var body: some View {
        TabView {
            HomeView(businessViewModel: businessViewModel)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            SearchView(businessViewModel: businessViewModel)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            
            JobsMainView()
                .environmentObject(authViewModel)
                .tabItem {
                    Label("Jobs", systemImage: "briefcase.fill")
                }
            
            MarketplaceView()
                .environmentObject(authViewModel)
                .tabItem {
                    Label("Marketplace", systemImage: "cart")
                }
            
            // ✅ Admin launcher tab (not the full dashboard with nested tabs)
            if authViewModel.userProfile?.isAdmin == true {
                AdminLauncherView(showingAdminPanel: $showingAdminPanel)
                    .tabItem {
                        Label("Admin", systemImage: "gear.badge")
                    }
            }
            
            ProfileView(authViewModel: authViewModel, businessViewModel: businessViewModel)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .environmentObject(businessViewModel)
        .environmentObject(authViewModel)
        .environmentObject(favoriteViewModel)
        // ✅ Present admin panel as full-screen modal
        .fullScreenCover(isPresented: $showingAdminPanel) {
            AdminDashboardView()
                .onDisappear {
                    // Optional: reset to dashboard tab when closing
                }
        }
    }
}

// MARK: - Admin Launcher View

struct AdminLauncherView: View {
    @Binding var showingAdminPanel: Bool
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: .blue.opacity(0.3), radius: 20, y: 10)
                    
                    Image(systemName: "gear.badge")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                
                // Title
                VStack(spacing: 8) {
                    Text("Admin Dashboard")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    Text("Manage your Javid platform")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Features
                VStack(spacing: 16) {
                    FeatureRow(icon: "building.2.fill", title: "Manage Businesses", color: .blue)
                    FeatureRow(icon: "person.3.fill", title: "User Management", color: .green)
                    FeatureRow(icon: "doc.text.fill", title: "Review Claims", color: .orange)
                    FeatureRow(icon: "chart.bar.fill", title: "Analytics & Reports", color: .purple)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Launch Button
                Button(action: { showingAdminPanel = true }) {
                    HStack {
                        Text("Open Dashboard")
                            .fontWeight(.semibold)
                        
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                )
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
}
