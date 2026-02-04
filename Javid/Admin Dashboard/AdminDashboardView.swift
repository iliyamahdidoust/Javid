//
//  AdminDashboardView.swift
//  Javid Admin Panel
//
//  Main container view for the admin dashboard with tab navigation
//

import SwiftUI
import FirebaseAuth

struct AdminDashboardView: View {
    @StateObject private var adminVM = AdminViewModel()
    @State private var selectedTab: AdminTab = .dashboard
    
    enum AdminTab: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case businesses = "Businesses"
        case claims = "Claims"
        case users = "Users"
        case reviews = "Reviews"
        case bookings = "Bookings"
        
        var id: String { rawValue }
        
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
            }
        }
        
        var badge: Int? {
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
            ForEach(AdminTab.allCases) { tab in
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
        .accentColor(.blue)
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
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Review Management View

struct ReviewManagementView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @State private var selectedRating: Int? = nil
    @State private var showingDeleteDialog = false
    @State private var reviewToDelete: Review?
    @State private var deletionReason = ""
    
    var filteredReviews: [Review] {
        var reviews = adminVM.filteredReviews
        
        if let rating = selectedRating {
            reviews = reviews.filter { Int($0.rating) == rating }
        }
        
        return reviews.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ratingFilterSection
            searchSection
            
            if adminVM.isLoading {
                LoadingView(message: "Loading reviews...")
            } else if filteredReviews.isEmpty {
                EmptyStateView(
                    icon: "star",
                    title: "No Reviews Found",
                    message: "No reviews match your filters"
                )
            } else {
                reviewsListSection
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Reviews (\(filteredReviews.count))")
        .navigationBarTitleDisplayMode(.large)
        .alert("Delete Review", isPresented: $showingDeleteDialog, presenting: reviewToDelete) { review in
            TextField("Reason for deletion", text: $deletionReason)
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    try? await adminVM.deleteReview(review, reason: deletionReason)
                    deletionReason = ""
                    reviewToDelete = nil
                }
            }
            .disabled(deletionReason.isEmpty)
        } message: { _ in
            Text("Please provide a reason for deleting this review. The user will be notified.")
        }
    }
    
    private var ratingFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                AdminFilterButton(
                    title: "All",
                    count: adminVM.allReviews.count,
                    isSelected: selectedRating == nil
                ) {
                    selectedRating = nil
                }
                
                ForEach(1...5, id: \.self) { rating in
                    AdminFilterButton(
                        title: "\(rating) ★",
                        count: adminVM.allReviews.filter { Int($0.rating) == rating }.count,
                        isSelected: selectedRating == rating
                    ) {
                        selectedRating = rating
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var searchSection: some View {
        AdminSearchBar(
            searchText: $adminVM.reviewFilter.searchText,
            placeholder: "Search reviews..."
        )
        .padding()
    }
    
    private var reviewsListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredReviews) { review in
                    ReviewCard(review: review) {
                        reviewToDelete = review
                        showingDeleteDialog = true
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Review Card

struct ReviewCard: View {
    let review: Review
    let onDelete: () -> Void
    
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
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete Review", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
            
            Text(review.comment)
                .font(.body)
            
            HStack {
                Text(formatDate(review.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if review.ownerResponse != nil {
                    Spacer()
                    AdminStatusBadge(text: "Owner Responded", color: .green)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Booking Management View

struct BookingManagementView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @State private var selectedStatus: BookingStatus? = nil
    @State private var showingCancelDialog = false
    @State private var bookingToCancel: Booking?
    @State private var cancellationReason = ""
    
    var filteredBookings: [Booking] {
        var bookings = adminVM.allBookings
        
        if let status = selectedStatus {
            bookings = bookings.filter { $0.status == status }
        }
        
        return bookings.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            statusFilterSection
            searchSection
            
            if adminVM.isLoading {
                LoadingView(message: "Loading bookings...")
            } else if filteredBookings.isEmpty {
                EmptyStateView(
                    icon: "calendar",
                    title: "No Bookings Found",
                    message: "No bookings match your filters"
                )
            } else {
                bookingsListSection
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Bookings (\(filteredBookings.count))")
        .navigationBarTitleDisplayMode(.large)
        .alert("Cancel Booking", isPresented: $showingCancelDialog, presenting: bookingToCancel) { booking in
            TextField("Reason for cancellation", text: $cancellationReason)
            Button("Cancel", role: .cancel) {}
            Button("Confirm Cancellation", role: .destructive) {
                Task {
                    try? await adminVM.cancelBooking(booking, reason: cancellationReason)
                    cancellationReason = ""
                    bookingToCancel = nil
                }
            }
            .disabled(cancellationReason.isEmpty)
        } message: { _ in
            Text("Please provide a reason for cancelling this booking. Both the user and business owner will be notified.")
        }
    }
    
    private var statusFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                AdminFilterButton(
                    title: "All",
                    count: adminVM.allBookings.count,
                    isSelected: selectedStatus == nil
                ) {
                    selectedStatus = nil
                }
                
                ForEach(BookingStatus.allCases, id: \.self) { status in
                    AdminFilterButton(
                        title: status.displayName,
                        count: adminVM.allBookings.filter { $0.status == status }.count,
                        isSelected: selectedStatus == status
                    ) {
                        selectedStatus = status
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var searchSection: some View {
        HStack {
            Text("\(filteredBookings.count) total bookings")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
    }
    
    private var bookingsListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredBookings) { booking in
                    BookingCard(booking: booking) {
                        bookingToCancel = booking
                        showingCancelDialog = true
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Booking Card

struct BookingCard: View {
    let booking: Booking
    let onCancel: () -> Void
    
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
                
                AdminStatusBadge(text: booking.status.displayName, color: colorForStatus(booking.status))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(icon: "calendar", text: formatDate(booking.date))
                DetailRow(icon: "clock", text: booking.timeSlot)
                DetailRow(icon: "person.2", text: "\(booking.partySize) people")
            }
            
            if booking.status == .pending || booking.status == .confirmed {
                Button(action: onCancel) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Cancel Booking")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.red))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }
    
    private func colorForStatus(_ status: BookingStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .confirmed: return .green
        case .cancelled: return .red
        case .completed: return .blue
        case .noShow: return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Filter Button

struct AdminFilterButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(isSelected ? Color.blue : Color.secondary))
            }
            .foregroundColor(isSelected ? .blue : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detail Row

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
