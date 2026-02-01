import SwiftUI

struct MainTabView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var businessViewModel = BusinessViewModel()
    @StateObject private var favoriteViewModel = FavoriteViewModel()
    
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
            
            ProfileView(authViewModel: authViewModel, businessViewModel: businessViewModel)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .environmentObject(businessViewModel)
        .environmentObject(authViewModel)
        .environmentObject(favoriteViewModel)
    }
}
