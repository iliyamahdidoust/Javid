//
//  BusinessManagementView.swift
//  Javid Admin Panel
//
//  Complete business management with CRUD operations, filters, and bulk actions
//

import SwiftUI

struct BusinessManagementView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @State private var selectedBusinesses: Set<String> = []
    @State private var showingDeleteConfirmation = false
    @State private var businessToDelete: Business?
    @State private var showingFilters = false
    @State private var sortOption: SortOption = .name
    @State private var showingExport = false
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case rating = "Rating"
        case reviews = "Reviews"
        case date = "Date Added"
        case city = "City"
    }
    
    var sortedBusinesses: [Business] {
        adminVM.filteredBusinesses.sorted { b1, b2 in
            switch sortOption {
            case .name:
                return b1.name < b2.name
            case .rating:
                return b1.rating > b2.rating
            case .reviews:
                return b1.reviewCount > b2.reviewCount
            case .date:
                return (b1.createdAt ?? Date.distantPast) > (b2.createdAt ?? Date.distantPast)
            case .city:
                return b1.city < b2.city
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            toolbarSection
            searchSection
            
            if adminVM.businessFilter.isActive {
                activeFiltersSection
            }
            
            if adminVM.isLoading {
                LoadingView(message: "Loading businesses...")
            } else if sortedBusinesses.isEmpty {
                EmptyStateView(
                    icon: "building.2",
                    title: "No Businesses Found",
                    message: adminVM.businessFilter.isActive ?
                        "Try adjusting your filters" :
                        "No businesses available"
                )
            } else {
                businessListSection
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Businesses (\(sortedBusinesses.count))")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingFilters) {
            BusinessFiltersView()
                .environmentObject(adminVM)
        }
        .alert("Delete Business", isPresented: $showingDeleteConfirmation, presenting: businessToDelete) { business in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    try? await adminVM.deleteBusiness(business)
                    businessToDelete = nil
                }
            }
        } message: { business in
            Text("Are you sure you want to delete '\(business.name)'? This will also delete all reviews, bookings, and associated data. This action cannot be undone.")
        }
    }
    
    // MARK: - Toolbar
    
    private var toolbarSection: some View {
        HStack(spacing: 12) {
            if !sortedBusinesses.isEmpty {
                Button(action: toggleSelectAll) {
                    HStack(spacing: 6) {
                        Image(systemName: selectedBusinesses.isEmpty ? "square" : "checkmark.square.fill")
                        Text(selectedBusinesses.isEmpty ? "Select All" : "Deselect")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(action: { sortOption = option }) {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option {
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
            
            Button(action: { showingFilters = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Filters")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if adminVM.businessFilter.isActive {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            
            Button(action: { showingExport = true }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.subheadline)
            }
            .sheet(isPresented: $showingExport) {
                if let url = ExportManager.exportBusinesses(sortedBusinesses) {
                    ShareSheet(items: [url])
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 2)
    }
    
    // MARK: - Search
    
    private var searchSection: some View {
        VStack(spacing: 12) {
            AdminSearchBar(
                searchText: $adminVM.businessFilter.searchText,
                placeholder: "Search businesses, categories, cities..."
            )
            
            if !selectedBusinesses.isEmpty {
                HStack(spacing: 12) {
                    Text("\(selectedBusinesses.count) selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: bulkDelete) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                    }
                    
                    Button(action: bulkFeature) {
                        HStack(spacing: 4) {
                            Image(systemName: "star")
                            Text("Feature")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    // MARK: - Active Filters
    
    private var activeFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let category = adminVM.businessFilter.category {
                    FilterTag(text: "Category: \(category)") {
                        adminVM.businessFilter.category = nil
                    }
                }
                
                if let city = adminVM.businessFilter.city {
                    FilterTag(text: "City: \(city)") {
                        adminVM.businessFilter.city = nil
                    }
                }
                
                if let rating = adminVM.businessFilter.rating {
                    FilterTag(text: "Rating: \(rating)+ stars") {
                        adminVM.businessFilter.rating = nil
                    }
                }
                
                if let claimStatus = adminVM.businessFilter.claimStatus {
                    FilterTag(text: "Status: \(claimStatus)") {
                        adminVM.businessFilter.claimStatus = nil
                    }
                }
                
                Button(action: {
                    adminVM.businessFilter.reset()
                }) {
                    Text("Clear All")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Business List
    
    private var businessListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(sortedBusinesses) { business in
                    BusinessRow(
                        business: business,
                        isSelected: selectedBusinesses.contains(business.id ?? ""),
                        onSelect: { toggleSelection(for: business) },
                        onDelete: {
                            businessToDelete = business
                            showingDeleteConfirmation = true
                        },
                        onToggleFeature: {
                            Task {
                                try? await adminVM.toggleBusinessFeature(business)
                            }
                        },
                        onToggleSuspension: {
                            Task {
                                try? await adminVM.toggleBusinessSuspension(business)
                            }
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - Actions
    
    private func toggleSelectAll() {
        if selectedBusinesses.count == sortedBusinesses.count {
            selectedBusinesses.removeAll()
        } else {
            selectedBusinesses = Set(sortedBusinesses.compactMap { $0.id })
        }
    }
    
    private func toggleSelection(for business: Business) {
        guard let id = business.id else { return }
        if selectedBusinesses.contains(id) {
            selectedBusinesses.remove(id)
        } else {
            selectedBusinesses.insert(id)
        }
    }
    
    private func bulkDelete() {
        let businesses = sortedBusinesses.filter { business in
            guard let id = business.id else { return false }
            return selectedBusinesses.contains(id)
        }
        
        Task {
            let result = await adminVM.performBulkOperation(
                items: businesses,
                operation: { try await adminVM.deleteBusiness($0) },
                operationName: "Delete Businesses"
            )
            selectedBusinesses.removeAll()
        }
    }
    
    private func bulkFeature() {
        let businesses = sortedBusinesses.filter { business in
            guard let id = business.id else { return false }
            return selectedBusinesses.contains(id)
        }
        
        Task {
            for business in businesses {
                try? await adminVM.toggleBusinessFeature(business)
            }
            selectedBusinesses.removeAll()
        }
    }
}

// MARK: - Business Row

struct BusinessRow: View {
    let business: Business
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onToggleFeature: () -> Void
    let onToggleSuspension: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            
            if let photoURL = business.photoURLs.first, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "building.2")
                            .foregroundColor(.white)
                    )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(business.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(business.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(business.city)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(String(format: "%.1f", business.rating))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    Text("\(business.reviewCount) reviews")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if business.isClaimable {
                        AdminStatusBadge(text: "Claimable", color: .green)
                    }
                    
                    if business.isClaimed {
                        AdminStatusBadge(text: "Claimed", color: .blue)
                    }
                }
            }
            
            Spacer()
            
            Menu {
                Button(action: onToggleFeature) {
                    Label(business.featured ? "Unfeature" : "Feature", systemImage: "star")
                }
                
                Button(action: onToggleSuspension) {
                    Label(business.suspended ? "Unsuspend" : "Suspend", systemImage: "hand.raised")
                }
                
                Divider()
                
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
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
}

// MARK: - Filter Tag

struct FilterTag: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blue)
        )
    }
}

// MARK: - Filters View

struct BusinessFiltersView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category") {
                    Picker("Select Category", selection: $adminVM.businessFilter.category) {
                        Text("All Categories").tag(nil as String?)
                        ForEach(adminVM.getCategories(), id: \.self) { category in
                            Text(category).tag(Optional(category))
                        }
                    }
                }
                
                Section("Location") {
                    Picker("City", selection: $adminVM.businessFilter.city) {
                        Text("All Cities").tag(nil as String?)
                        ForEach(adminVM.getCities(), id: \.self) { city in
                            Text(city).tag(Optional(city))
                        }
                    }
                    
                    Picker("Country", selection: $adminVM.businessFilter.country) {
                        Text("All Countries").tag(nil as String?)
                        ForEach(adminVM.getCountries(), id: \.self) { country in
                            Text(country).tag(Optional(country))
                        }
                    }
                }
                
                Section("Rating") {
                    Picker("Minimum Rating", selection: $adminVM.businessFilter.rating) {
                        Text("Any Rating").tag(nil as Int?)
                        ForEach(1...5, id: \.self) { rating in
                            Text("\(rating)+ stars").tag(Optional(rating))
                        }
                    }
                }
                
                Section("Claim Status") {
                    Picker("Status", selection: $adminVM.businessFilter.claimStatus) {
                        Text("All").tag(nil as String?)
                        Text("Claimable").tag(Optional("claimable"))
                        Text("Claimed").tag(Optional("claimed"))
                        Text("Unclaimed").tag(Optional("unclaimed"))
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        adminVM.businessFilter.reset()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
