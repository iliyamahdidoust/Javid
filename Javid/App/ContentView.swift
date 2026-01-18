import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        MainTabView(authViewModel: authViewModel)
    }
}

#Preview {
    ContentView()
}
