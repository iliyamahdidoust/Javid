import SwiftUI

struct MainTabView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var businessViewModel = BusinessViewModel()
    
    var body: some View {
        TabView {
            HomeView(businessViewModel: businessViewModel)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            ProfileView(authViewModel: authViewModel, businessViewModel: businessViewModel)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .environmentObject(businessViewModel)
        .environmentObject(authViewModel)
    }
}
