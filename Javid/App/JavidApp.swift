import SwiftUI
import FirebaseCore

@main
struct JavidApp: App {
    init() {
        FirebaseApp.configure()
        
        // Add memory warning observer to clear caches
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("⚠️ Memory Warning - Clearing caches")
            ImageCacheManager.shared.clearCache()
            URLCache.shared.removeAllCachedResponses()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    class AppDelegate: NSObject, UIApplicationDelegate {
        func application(_ application: UIApplication,
                         didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
            FirebaseApp.configure()
            return true
        }
    }
}
