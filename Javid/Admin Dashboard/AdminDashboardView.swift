//
//  AdminDashboardView.swift
//  Javid Admin Dashboard
//
//  Main container view for the admin dashboard with tab navigation
//

import SwiftUI
import FirebaseAuth

struct AdminDashboardView: View {
    @StateObject private var adminVM = AdminViewModel()
    @State private var selectedTab: AdminTab = .dashboard
    
    enum AdminTab: String, CaseIterable {
        case dashboard = "Dashboard"
        case businesses = "Businesses"
        case claims = "Claims"
        case users = "Users"
        case reviews = "Reviews"
        case bookings = "Bookings"
        case analytics = "Analytics"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .dashboard:
                return "square.grid.2x2.fill"
            case .businesses:
                return "building.2.fill"
            case .claims:
                return "doc.text.fill"
            case .users:
                return "person.3.fill"
            case .reviews:
                return "star.fill"
            case .bookings:
                return "calendar.badge.clock"
            case .analytics:
                return "chart.bar.fill"
            case .settings:
                return "gear"
            }
        }
        
        var badge: Int? {
            // This would be dynamically calculated
            return nil
        }
    }
    
    var body: some View {
        Group {
            if !adminVM.isAuthenticated {
                LoginRequiredView()
            } else if !adminVM.isAdmin {
                AccessDeniedView()
            } else {
                mainDashboard
            }
        }
        .alert("Error", isPresented: .constant(adminVM.errorMessage != nil), presenting: adminVM.errorMessage) { _ in
            Button("OK") {
                adminVM.clearMessages()
            }
        } message: { error in
            Text(error)
        }
        .alert("Success", isPresented: .constant(adminVM.successMessage != nil), presenting: adminVM.successMessage) { _ in
            Button("OK") {
                adminVM.clearMessages()
            }
        } message: { message in
            Text(message)
        }
    }
    
    // MARK: - Main Dashboard
    
    private var mainDashboard: some View {
        TabView(selection: $selectedTab) {
            ForEach(AdminTab.allCases, id: \.self) { tab in
                NavigationView {
                    viewForTab(tab)
                }
                .tabItem {
                    Label(tab.rawValue, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
        .environmentObject(adminVM)
    }
    
    // MARK: - View Routing
    
    @ViewBuilder
    private func viewForTab(_ tab: AdminTab) -> some View {
        switch tab {
        case .dashboard:
            DashboardHomeView()
        case .businesses:
            BusinessManagementView()
        case .claims:
            ClaimManagementView()
        case .users:
            UserManagementView()
        case .reviews:
            ReviewManagementView()
        case .bookings:
            BookingManagementView()
        case .analytics:
            AnalyticsView()
        case .settings:
            AdminSettingsView()
        }
    }
}

// MARK: - Login Required View

struct LoginRequiredView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 12) {
                Text("Authentication Required")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Please sign in to access the admin dashboard")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                // Navigate to login
            }) {
                Text("Sign In")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 200)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
            }
        }
        .padding()
    }
}

// MARK: - Access Denied View

struct AccessDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            VStack(spacing: 12) {
                Text("Access Denied")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("You do not have permission to access the admin dashboard. Please contact an administrator if you believe this is an error.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: {
                // Sign out
                try? Auth.auth().signOut()
            }) {
                Text("Sign Out")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 200)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red)
                    )
            }
        }
        .padding()
    }
}

// MARK: - Review Management View (Placeholder)

struct ReviewManagementView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Review Management")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("\(adminVM.allReviews.count) total reviews")
                    .foregroundColor(.secondary)
                
                LazyVStack(spacing: 12) {
                    ForEach(adminVM.allReviews) { review in
                        ReviewCard(review: review)
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Reviews")
    }
}

struct ReviewCard: View {
    let review: Review
    @EnvironmentObject var adminVM: AdminViewModel
    @State private var showingDeleteConfirmation = false
    @State private var deletionReason = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(review.userName)
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        ForEach(0..<5) { star in
                            Image(systemName: star < Int(review.rating) ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                Menu {
                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label("Delete Review", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
            
            Text(review.comment)
                .font(.body)
            
            Text(formatDate(review.createdAt))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
        .alert("Delete Review", isPresented: $showingDeleteConfirmation) {
            TextField("Reason for deletion", text: $deletionReason)
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    try? await adminVM.deleteReview(review, reason: deletionReason)
                    deletionReason = ""
                }
            }
            .disabled(deletionReason.isEmpty)
        } message: {
            Text("Please provide a reason for deleting this review. The user will be notified.")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Booking Management View (Placeholder)

struct BookingManagementView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Booking Management")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("\(adminVM.allBookings.count) total bookings")
                    .foregroundColor(.secondary)
                
                LazyVStack(spacing: 12) {
                    ForEach(adminVM.allBookings) { booking in
                        BookingCard(booking: booking)
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Bookings")
    }
}

struct BookingCard: View {
    let booking: Booking
    @EnvironmentObject var adminVM: AdminViewModel
    @State private var showingCancelDialog = false
    @State private var cancellationReason = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.businessName)
                        .font(.headline)
                    
                    Text(booking.userName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                AdminStatusBadge(text: booking.status.rawValue.capitalized, color: colorForBookingStatus(booking.status))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(icon: "calendar", text: formatDate(booking.date))
                DetailRow(icon: "clock", text: booking.timeSlot)
                DetailRow(icon: "person.2", text: "\(booking.partySize) people")
            }
            
            if booking.status == .pending || booking.status == .confirmed {
                Button(action: { showingCancelDialog = true }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Cancel Booking")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red)
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
        .alert("Cancel Booking", isPresented: $showingCancelDialog) {
            TextField("Reason for cancellation", text: $cancellationReason)
            Button("Cancel", role: .cancel) {}
            Button("Confirm Cancellation", role: .destructive) {
                Task {
                    try? await adminVM.cancelBooking(booking, reason: cancellationReason)
                    cancellationReason = ""
                }
            }
            .disabled(cancellationReason.isEmpty)
        } message: {
            Text("Please provide a reason for cancelling this booking. Both the user and business owner will be notified.")
        }
    }
    
    private func colorForBookingStatus(_ status: BookingStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .confirmed:
            return .green
        case .cancelled:
            return .red
        case .completed:
            return .blue
        case .noShow:
            return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Detail Row View

struct DetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(text)
                .foregroundColor(.primary)
                .font(.subheadline)
        }
    }
}

// MARK: - Analytics View (Placeholder)

struct AnalyticsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Analytics Dashboard")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Comprehensive analytics and reports coming soon")
                    .foregroundColor(.secondary)
                
                // Placeholder for charts
                VStack(spacing: 16) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .overlay(Text("Business Growth Chart").foregroundColor(.secondary))
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .overlay(Text("User Activity Chart").foregroundColor(.secondary))
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .overlay(Text("Revenue Chart").foregroundColor(.secondary))
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Analytics")
    }
}

// MARK: - Settings View (Placeholder)

struct AdminSettingsView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    
    var body: some View {
        Form {
            Section("Account") {
                if let user = adminVM.currentUser {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(user.name)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(user.email)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Dashboard") {
                Toggle("Enable Real-time Updates", isOn: .constant(true))
                Toggle("Show Notifications", isOn: .constant(true))
            }
            
            Section("Data Management") {
                Button("Export All Data") {
                    // Export functionality
                }
                
                Button("Clear Cache") {
                    // Clear cache
                }
            }
            
            Section {
                Button("Sign Out") {
                    try? Auth.auth().signOut()
                    adminVM.checkAdminStatus()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Preview

struct AdminDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        AdminDashboardView()
    }
}

