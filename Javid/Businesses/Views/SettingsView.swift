import SwiftUI
import UserNotifications
import CoreLocation

struct SettingsView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var locationManager = LocationManager()
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    private let notificationManager = NotificationManager.shared
    
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("locationEnabled") private var locationEnabled = true
    @AppStorage("marketingEmails") private var marketingEmails = false
    @AppStorage("biometricEnabled") private var biometricEnabled = false
    @AppStorage("autoPlayVideos") private var autoPlayVideos = true
    @AppStorage("dataSaverMode") private var dataSaverMode = false
    @AppStorage("languageCode") private var languageCode = "en"
    @AppStorage("searchRadius") private var searchRadius = 10.0
    
    @State private var showDeleteAccountAlert = false
    @State private var showLogoutAlert = false
    @State private var showClearCacheAlert = false
    @State private var isDeleting = false
    @State private var isClearingCache = false
    @State private var showNotificationPermissionAlert = false
    @State private var showLocationPermissionAlert = false
    @State private var cacheSize = "Calculating..."
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                List {
                    // Notifications Section
                    Section {
                        Toggle(isOn: Binding(
                            get: { notificationsEnabled },
                            set: { newValue in
                                handleNotificationToggle(newValue)
                            }
                        )) {
                            Label("Push Notifications", systemImage: "bell.fill")
                        }
                        .tint(AppColors.primary)
                        
                        Toggle(isOn: $marketingEmails) {
                            Label("Marketing Emails", systemImage: "envelope.fill")
                        }
                        .tint(AppColors.primary)
                        .onChange(of: marketingEmails) { newValue in
                            handleMarketingEmailsToggle(newValue)
                        }
                    } header: {
                        Text("Notifications")
                    }
                    
                    // Privacy Section
                    Section {
                        Toggle(isOn: Binding(
                            get: { locationEnabled },
                            set: { newValue in
                                handleLocationToggle(newValue)
                            }
                        )) {
                            Label("Location Services", systemImage: "location.fill")
                        }
                        .tint(AppColors.primary)
                        
                        Toggle(isOn: $biometricEnabled) {
                            Label("Face ID / Touch ID", systemImage: "faceid")
                        }
                        .tint(AppColors.primary)
                        
                        NavigationLink {
                            PrivacyPolicyView()
                        } label: {
                            Label("Privacy Policy", systemImage: "hand.raised.fill")
                        }
                        
                        NavigationLink {
                            TermsOfServiceView()
                        } label: {
                            Label("Terms of Service", systemImage: "doc.text.fill")
                        }
                    } header: {
                        Text("Privacy & Legal")
                    }
                    
                    // Preferences Section
                    Section {
                        HStack {
                            Label("Search Radius", systemImage: "scope")
                            Spacer()
                            Picker("", selection: $searchRadius) {
                                Text("5 km").tag(5.0)
                                Text("10 km").tag(10.0)
                                Text("25 km").tag(25.0)
                                Text("50 km").tag(50.0)
                                Text("100 km").tag(100.0)
                            }
                            .pickerStyle(.menu)
                        }
                        
                        HStack {
                            Label("Language", systemImage: "globe")
                            Spacer()
                            Picker("", selection: $languageCode) {
                                Text("English").tag("en")
                                Text("Spanish").tag("es")
                                Text("French").tag("fr")
                                Text("German").tag("de")
                            }
                            .pickerStyle(.menu)
                        }
                        
                        Toggle(isOn: $autoPlayVideos) {
                            Label("Auto-play Videos", systemImage: "play.rectangle.fill")
                        }
                        .tint(AppColors.primary)
                        
                        Toggle(isOn: $dataSaverMode) {
                            Label("Data Saver Mode", systemImage: "antenna.radiowaves.left.and.right.slash")
                        }
                        .tint(AppColors.primary)
                    } header: {
                        Text("Preferences")
                    }
                    
                    // Appearance Section
                    Section {
                        Picker("Theme", selection: $darkModeEnabled) {
                            Label("Light", systemImage: "sun.max.fill")
                                .tag(false)
                            Label("Dark", systemImage: "moon.fill")
                                .tag(true)
                        }
                        .pickerStyle(.menu)
                        .onChange(of: darkModeEnabled) { newValue in
                            applyTheme(isDark: newValue)
                        }
                    } header: {
                        Text("Appearance")
                    }
                    
                    // Storage Section
                    Section {
                        HStack {
                            Label("Cache Size", systemImage: "externaldrive.fill")
                            Spacer()
                            Text(cacheSize)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Button(action: {
                            showClearCacheAlert = true
                        }) {
                            HStack {
                                Label("Clear Cache", systemImage: "trash.fill")
                                    .foregroundColor(AppColors.warning)
                                if isClearingCache {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isClearingCache)
                    } header: {
                        Text("Storage")
                    }
                    
                    // About Section
                    Section {
                        HStack {
                            Label("Version", systemImage: "info.circle.fill")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        NavigationLink {
                            AboutView()
                        } label: {
                            Label("About Us", systemImage: "building.2.fill")
                        }
                        
                        Link(destination: URL(string: "mailto:support@javid.com")!) {
                            Label("Contact Support", systemImage: "questionmark.circle.fill")
                        }
                        
                        Button(action: {
                            rateApp()
                        }) {
                            Label("Rate Us", systemImage: "star.fill")
                        }
                        
                        Button(action: {
                            shareApp()
                        }) {
                            Label("Share App", systemImage: "square.and.arrow.up")
                        }
                    } header: {
                        Text("About")
                    }
                    
                    // Account Actions Section
                    Section {
                        Button(action: {
                            showLogoutAlert = true
                        }) {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(AppColors.error)
                        }
                        
                        Button(action: {
                            showDeleteAccountAlert = true
                        }) {
                            if isDeleting {
                                HStack {
                                    Label("Deleting...", systemImage: "trash.fill")
                                    Spacer()
                                    ProgressView()
                                }
                                .foregroundColor(AppColors.error)
                            } else {
                                Label("Delete Account", systemImage: "trash.fill")
                                    .foregroundColor(AppColors.error)
                            }
                        }
                        .disabled(isDeleting)
                    } header: {
                        Text("Account")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .alert("Sign Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authViewModel.signOut()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
            .alert("Clear Cache", isPresented: $showClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("This will free up \(cacheSize) of storage space.")
            }
            .alert("Notification Permission Required", isPresented: $showNotificationPermissionAlert) {
                Button("Open Settings") {
                    openAppSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable notifications in Settings to receive alerts.")
            }
            .alert("Location Permission Required", isPresented: $showLocationPermissionAlert) {
                Button("Open Settings") {
                    openAppSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable location services in Settings to use this feature.")
            }
            .preferredColorScheme(darkModeEnabled ? .dark : .light)
            .onAppear {
                syncNotificationState()
                syncLocationState()
                calculateCacheSize()
            }
        }
    }
    
    // MARK: - Notification Handling
    private func syncNotificationState() {
        notificationManager.checkAuthorizationStatus()
    }
    
    private func handleNotificationToggle(_ enabled: Bool) {
        if enabled {
            requestNotificationPermission()
        } else {
            notificationsEnabled = false
            notificationManager.removeAllPendingNotifications()
        }
    }
    
    private func requestNotificationPermission() {
        notificationManager.requestAuthorization { granted in
            DispatchQueue.main.async {
                if granted {
                    notificationsEnabled = true
                } else {
                    notificationsEnabled = false
                    showNotificationPermissionAlert = true
                }
            }
        }
    }
    
    // MARK: - Marketing Emails Handling
    private func handleMarketingEmailsToggle(_ enabled: Bool) {
        Task {
            do {
                try await updateMarketingPreference(enabled: enabled)
            } catch {
                DispatchQueue.main.async {
                    marketingEmails = !enabled
                }
            }
        }
    }
    
    private func updateMarketingPreference(enabled: Bool) async throws {
        guard let url = URL(string: "https://api.yourapp.com/user/marketing-preferences") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["marketingEmails": enabled]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Location Handling
    private func syncLocationState() {
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationEnabled = true
        case .denied, .restricted:
            locationEnabled = false
        default:
            break
        }
    }
    
    private func handleLocationToggle(_ enabled: Bool) {
        if enabled {
            requestLocationPermission()
        } else {
            locationEnabled = false
            locationManager.stopUpdating()
        }
    }
    
    private func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestPermission()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                checkLocationPermission()
            }
        case .authorizedWhenInUse, .authorizedAlways:
            locationEnabled = true
            locationManager.startUpdating()
        case .denied, .restricted:
            locationEnabled = false
            showLocationPermissionAlert = true
        @unknown default:
            locationEnabled = false
        }
    }
    
    private func checkLocationPermission() {
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationEnabled = true
            locationManager.startUpdating()
        case .denied, .restricted:
            locationEnabled = false
            showLocationPermissionAlert = true
        default:
            locationEnabled = false
        }
    }
    
    // MARK: - Theme Handling
    private func applyTheme(isDark: Bool) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.first?.overrideUserInterfaceStyle = isDark ? .dark : .light
        }
    }
    
    // MARK: - Storage Management
    private func calculateCacheSize() {
        Task {
            let size = await getCacheSize()
            await MainActor.run {
                cacheSize = size
            }
        }
    }
    
    private func getCacheSize() async -> String {
        do {
            let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let fileURLs = try FileManager.default.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: [.fileSizeKey])
            
            let totalSize = fileURLs.reduce(0) { size, url in
                let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return size + fileSize
            }
            
            return ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
        } catch {
            return "Unknown"
        }
    }
    
    private func clearCache() {
        isClearingCache = true
        
        Task {
            do {
                let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                let fileURLs = try FileManager.default.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)
                
                for fileURL in fileURLs {
                    try FileManager.default.removeItem(at: fileURL)
                }
                
                await MainActor.run {
                    isClearingCache = false
                    cacheSize = "0 bytes"
                }
            } catch {
                await MainActor.run {
                    isClearingCache = false
                }
            }
        }
    }
    
    // MARK: - App Actions
    private func rateApp() {
        if let url = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
    
    private func shareApp() {
        let shareText = "Check out Javid - Connecting businesses with customers!"
        let shareURL = URL(string: "https://yourapp.com")!
        
        let activityVC = UIActivityViewController(activityItems: [shareText, shareURL], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    // MARK: - Account Actions
    private func deleteAccount() {
        isDeleting = true
        
        Task {
            await authViewModel.deleteAccount { success, message in
                isDeleting = false
                if success {
                    dismiss()
                }
            }
        }
    }
    
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Privacy Policy")
                    .font(AppFonts.title1)
                    .fontWeight(.bold)
                
                Text("Last updated: \(Date().formatted(date: .long, time: .omitted))")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                
                Group {
                    sectionTitle("Information We Collect")
                    sectionText("We collect information you provide directly to us, including your name, email address, and business information.")
                    
                    sectionTitle("How We Use Your Information")
                    sectionText("We use the information we collect to provide, maintain, and improve our services.")
                    
                    sectionTitle("Data Security")
                    sectionText("We implement appropriate security measures to protect your personal information.")
                    
                    sectionTitle("Contact Us")
                    sectionText("If you have questions about this Privacy Policy, please contact us at support@javid.com")
                }
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColors.background)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AppFonts.title3)
            .fontWeight(.semibold)
            .foregroundColor(AppColors.textPrimary)
            .padding(.top, AppSpacing.md)
    }
    
    private func sectionText(_ text: String) -> some View {
        Text(text)
            .font(AppFonts.body)
            .foregroundColor(AppColors.textSecondary)
    }
}

// MARK: - Terms of Service View
struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Terms of Service")
                    .font(AppFonts.title1)
                    .fontWeight(.bold)
                
                Text("Last updated: \(Date().formatted(date: .long, time: .omitted))")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                
                Group {
                    sectionTitle("Acceptance of Terms")
                    sectionText("By accessing our service, you agree to be bound by these terms.")
                    
                    sectionTitle("User Responsibilities")
                    sectionText("You are responsible for maintaining the confidentiality of your account.")
                    
                    sectionTitle("Prohibited Activities")
                    sectionText("You may not use our service for any illegal or unauthorized purpose.")
                    
                    sectionTitle("Termination")
                    sectionText("We reserve the right to terminate or suspend your account at our discretion.")
                }
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColors.background)
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AppFonts.title3)
            .fontWeight(.semibold)
            .foregroundColor(AppColors.textPrimary)
            .padding(.top, AppSpacing.md)
    }
    
    private func sectionText(_ text: String) -> some View {
        Text(text)
            .font(AppFonts.body)
            .foregroundColor(AppColors.textSecondary)
    }
}

// MARK: - About View
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                Image(systemName: "building.2.crop.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(AppColors.primary)
                    .padding(.top, AppSpacing.xl)
                
                VStack(spacing: AppSpacing.sm) {
                    Text("Javid")
                        .font(AppFonts.title1)
                        .fontWeight(.bold)
                    
                    Text("Version 1.0.0")
                        .font(AppFonts.callout)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Text("Connecting businesses with customers, one review at a time.")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                
                VStack(spacing: AppSpacing.md) {
                    infoRow(icon: "envelope.fill", title: "Email", value: "support@javid.com")
                    infoRow(icon: "globe", title: "Website", value: "www.javid.com")
                    infoRow(icon: "building.2.fill", title: "Company", value: "Javid Inc.")
                }
                .padding(.horizontal, AppSpacing.lg)
                
                Text("© 2024 Javid. All rights reserved.")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.top, AppSpacing.xl)
            }
            .padding(.vertical, AppSpacing.lg)
        }
        .background(AppColors.background)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(AppFonts.callout)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(AppFonts.callout)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
    }
}
