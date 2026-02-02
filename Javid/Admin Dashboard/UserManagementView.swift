//
//  UserManagementView.swift
//  Javid Admin Dashboard
//
//  Complete user management with role changes, suspensions, and user details
//

import SwiftUI
import FirebaseAuth

struct UserManagementView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @State private var selectedUsers: Set<String> = []
    @State private var showingUserDetail: UserProfile?
    @State private var showingSuspendDialog = false
    @State private var userToSuspend: UserProfile?
    @State private var suspensionReason = ""
    @State private var showingDeleteConfirmation = false
    @State private var userToDelete: UserProfile?
    @State private var sortBy: UserSortOption = .name
    @State private var roleFilter: String? = nil
    
    enum UserSortOption: String, CaseIterable {
        case name = "Name"
        case email = "Email"
        case joinDate = "Join Date"
        case businessCount = "Businesses Owned"
    }
    
    var filteredSortedUsers: [UserProfile] {
        var users = adminVM.filteredUsers
        
        if let role = roleFilter {
            users = users.filter { user in
                switch role {
                case "admin":
                    return user.isAdmin
                case "business_owner":
                    return user.isBusinessOwner && !user.isAdmin
                case "regular":
                    return !user.isBusinessOwner && !user.isAdmin
                default:
                    return true
                }
            }
        }
        
        return users.sorted { u1, u2 in
            switch sortBy {
            case .name:
                return u1.name < u2.name
            case .email:
                return u1.email < u2.email
            case .joinDate:
                return (u1.createdAt ?? .distantPast) > (u2.createdAt ?? .distantPast)
            case .businessCount:
                return (u1.claimedBusinessIds?.count ?? 0) > (u2.claimedBusinessIds?.count ?? 0)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbarSection
            
            // Search and Filters
            searchSection
            
            // Users List
            if adminVM.isLoading {
                LoadingView(message: "Loading users...")
            } else if filteredSortedUsers.isEmpty {
                EmptyStateView(
                    icon: "person.3",
                    title: "No Users Found",
                    message: "Try adjusting your filters"
                )
            } else {
                usersListSection
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Users (\(filteredSortedUsers.count))")
        .sheet(item: $showingUserDetail) { user in
            UserDetailView(user: user)
                .environmentObject(adminVM)
        }
        .alert("Suspend User", isPresented: $showingSuspendDialog, presenting: userToSuspend) { user in
            TextField("Reason for suspension", text: $suspensionReason)
            Button("Cancel", role: .cancel) {}
            Button("Suspend", role: .destructive) {
                Task {
                    try? await adminVM.suspendUser(user: user, reason: suspensionReason)
                    suspensionReason = ""
                    userToSuspend = nil
                }
            }
            .disabled(suspensionReason.isEmpty)
        } message: { user in
            Text("Please provide a reason for suspending \(user.name). They will be notified.")
        }
        .alert("Delete User", isPresented: $showingDeleteConfirmation, presenting: userToDelete) { user in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    try? await adminVM.deleteUser(user: user)
                    userToDelete = nil
                }
            }
        } message: { user in
            Text("Are you sure you want to delete \(user.name)? This will permanently delete their account and all associated data. This action cannot be undone.")
        }
    }
    
    // MARK: - Toolbar Section
    
    private var toolbarSection: some View {
        HStack(spacing: 12) {
            // Role Filter
            Menu {
                Button(action: { roleFilter = nil }) {
                    HStack {
                        Text("All Users")
                        if roleFilter == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Button(action: { roleFilter = "admin" }) {
                    HStack {
                        Text("Admins")
                        if roleFilter == "admin" {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Button(action: { roleFilter = "business_owner" }) {
                    HStack {
                        Text("Business Owners")
                        if roleFilter == "business_owner" {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Button(action: { roleFilter = "regular" }) {
                    HStack {
                        Text("Regular Users")
                        if roleFilter == "regular" {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.circle")
                    Text(roleFilter == nil ? "All Roles" : (roleFilter == "admin" ? "Admins" : roleFilter == "business_owner" ? "Business Owners" : "Regular"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            // Sort Menu
            Menu {
                ForEach(UserSortOption.allCases, id: \.self) { option in
                    Button(action: { sortBy = option }) {
                        HStack {
                            Text(option.rawValue)
                            if sortBy == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text("Sort")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            // Export Button
            Button(action: {
                if let url = ExportManager.exportUsers(filteredSortedUsers) {
                    // Present share sheet
                }
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 2)
    }
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        AdminSearchBar(
            searchText: $adminVM.userFilter.searchText,
            placeholder: "Search by name, email, or phone..."
        )
        .onChange(of: adminVM.userFilter.searchText) { _ in
            adminVM.applyUserFilter()
        }
        .padding()
    }
    
    // MARK: - Users List Section
    
    private var usersListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredSortedUsers) { user in
                    UserRow(
                        user: user,
                        onTap: { showingUserDetail = user },
                        onPromoteToBusinessOwner: {
                            Task {
                                try? await adminVM.promoteToBusinessOwner(user: user)
                            }
                        },
                        onPromoteToAdmin: {
                            Task {
                                try? await adminVM.promoteToAdmin(user: user)
                            }
                        },
                        onDemoteAdmin: {
                            Task {
                                try? await adminVM.demoteAdmin(user: user)
                            }
                        },
                        onSuspend: {
                            userToSuspend = user
                            showingSuspendDialog = true
                        },
                        onDelete: {
                            userToDelete = user
                            showingDeleteConfirmation = true
                        }
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - User Row Component

struct UserRow: View {
    let user: UserProfile
    let onTap: () -> Void
    let onPromoteToBusinessOwner: () -> Void
    let onPromoteToAdmin: () -> Void
    let onDemoteAdmin: () -> Void
    let onSuspend: () -> Void
    let onDelete: () -> Void
    
    var roleText: String {
        if user.isAdmin {
            return "Admin"
        } else if user.isBusinessOwner {
            return "Business Owner"
        } else {
            return "Regular User"
        }
    }
    
    var roleColor: Color {
        if user.isAdmin {
            return .purple
        } else if user.isBusinessOwner {
            return .blue
        } else {
            return .gray
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile Image
                if let imageURL = user.profileImageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(roleColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(user.name.prefix(1).uppercased())
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(roleColor)
                        )
                }
                
                // User Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(user.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        AdminStatusBadge(text: roleText, color: roleColor)
                        
                        if let businessCount = user.claimedBusinessIds?.count, businessCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "building.2.fill")
                                    .font(.caption2)
                                Text("\(businessCount)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        Text("Joined \(formatDate(user.createdAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Actions Menu
                Menu {
                    Button(action: onTap) {
                        Label("View Details", systemImage: "eye")
                    }
                    
                    Divider()
                    
                    if !user.isBusinessOwner && !user.isAdmin {
                        Button(action: onPromoteToBusinessOwner) {
                            Label("Promote to Business Owner", systemImage: "arrow.up.circle")
                        }
                    }
                    
                    if !user.isAdmin {
                        Button(action: onPromoteToAdmin) {
                            Label("Promote to Admin", systemImage: "shield")
                        }
                    }
                    
                    if user.isAdmin && user.uid != Auth.auth().currentUser?.uid {
                        Button(action: onDemoteAdmin) {
                            Label("Demote from Admin", systemImage: "arrow.down.circle")
                        }
                    }
                    
                    Divider()
                    
                    Button(action: onSuspend) {
                        Label("Suspend User", systemImage: "hand.raised")
                    }
                    
                    if user.uid != Auth.auth().currentUser?.uid {
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete User", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - User Detail View

struct UserDetailView: View {
    let user: UserProfile
    @EnvironmentObject var adminVM: AdminViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeaderSection
                    
                    // User Information
                    userInfoSection
                    
                    // Account Statistics
                    statisticsSection
                    
                    // Businesses Owned (if any)
                    if let businessIds = user.claimedBusinessIds, !businessIds.isEmpty {
                        businessesSection(businessIds: businessIds)
                    }
                    
                    // Activity Section
                    activitySection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("User Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // Profile Image
            if let imageURL = user.profileImageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Text(user.name.prefix(1).uppercased())
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundColor(.blue)
                    )
            }
            
            VStack(spacing: 8) {
                Text(user.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    if user.isAdmin {
                        AdminStatusBadge(text: "Admin", color: .purple)
                    }
                    
                    if user.isBusinessOwner {
                        AdminStatusBadge(text: "Business Owner", color: .blue)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }
    
    // MARK: - User Info Section
    
    private var userInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminSectionHeader(title: "Account Information", icon: "person.fill")
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(icon: "person", title: "User ID", subtitle: user.uid)
                InfoRow(icon: "phone.fill", title: "Phone Number", subtitle: user.phoneNumber ?? "Not provided")
                InfoRow(icon: "calendar", title: "Join Date", subtitle: formatDate(user.createdAt))
                
                if let bio = user.bio, !bio.isEmpty {
                    InfoRow(icon: "text.alignleft", title: "Bio", subtitle: bio)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
        }
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminSectionHeader(title: "Statistics", icon: "chart.bar.fill")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                UserManagementStatCard(
                    title: "Businesses Owned",
                    value: "\(user.claimedBusinessIds?.count ?? 0)",
                    icon: "building.2.fill",
                    color: .blue
                )
                
                UserManagementStatCard(
                    title: "Reviews Written",
                    value: "0", // Would need to fetch
                    icon: "star.fill",
                    color: .orange
                )
                
                UserManagementStatCard(
                    title: "Favorites",
                    value: "0", // Would need to fetch
                    icon: "heart.fill",
                    color: .red
                )
                
                UserManagementStatCard(
                    title: "Bookings",
                    value: "0", // Would need to fetch
                    icon: "calendar.badge.clock",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Businesses Section
    
    private func businessesSection(businessIds: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminSectionHeader(title: "Owned Businesses", icon: "building.2.fill")
            
            VStack(spacing: 12) {
                ForEach(businessIds, id: \.self) { businessId in
                    if let business = adminVM.allBusinesses.first(where: { $0.id == businessId }) {
                        BusinessQuickCard(business: business)
                    }
                }
            }
        }
    }
    
    // MARK: - Activity Section
    
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminSectionHeader(title: "Recent Activity", icon: "clock.fill")
            
            Text("No recent activity")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                )
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Stat Card Component

struct UserManagementStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }
}

// MARK: - Business Quick Card Component

struct BusinessQuickCard: View {
    let business: Business
    
    var body: some View {
        HStack(spacing: 12) {
            if let photoURL = business.photoURLs.first, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(business.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 6) {
                    Text(business.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text(String(format: "%.1f", business.rating))
                            .font(.caption)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }
}

