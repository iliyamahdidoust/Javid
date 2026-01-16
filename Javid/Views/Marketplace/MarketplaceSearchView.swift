import SwiftUI

struct MarketplaceSearchView: View {
    @ObservedObject var marketplaceViewModel: MarketplaceViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var searchText = ""
    @State private var selectedCategory: MarketplaceCategory? = nil
    @State private var selectedCondition: ItemCondition? = nil
    @State private var minPrice: Double = 0
    @State private var maxPrice: Double = 10000
    @State private var showingFilters = false
    
    var searchResults: [MarketplaceItem] {
        var results = marketplaceViewModel.items
        
        // Apply search text
        if !searchText.isEmpty {
            results = results.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.description.localizedCaseInsensitiveContains(searchText) ||
                item.location.localizedCaseInsensitiveContains(searchText) ||
                item.category.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply category filter
        if let category = selectedCategory {
            results = results.filter { $0.category == category }
        }
        
        // Apply condition filter
        if let condition = selectedCondition {
            results = results.filter { $0.condition == condition }
        }
        
        // Apply price filter
        results = results.filter { $0.price >= minPrice && $0.price <= maxPrice }
        
        return results
    }
    
    var hasActiveFilters: Bool {
        return selectedCategory != nil || selectedCondition != nil || minPrice > 0 || maxPrice < 10000
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: AppSpacing.md) {
                // Back Button
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(AppColors.surface)
                        .cornerRadius(AppRadius.full)
                }
                
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.textSecondary)
                    
                    TextField("Search items...", text: $searchText)
                        .font(AppFonts.body)
                        .autocapitalization(.none)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                .padding(AppSpacing.sm)
                .background(AppColors.surface)
                .cornerRadius(AppRadius.full)
                
                // Filters Button
                Button(action: {
                    showingFilters = true
                }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(AppColors.surface)
                            .cornerRadius(AppRadius.full)
                        
                        if hasActiveFilters {
                            Circle()
                                .fill(AppColors.primary)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.background)
            
            // Active Filters
            if hasActiveFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let category = selectedCategory {
                            FilterChip(text: category.rawValue, icon: category.icon) {
                                selectedCategory = nil
                            }
                        }
                        
                        if let condition = selectedCondition {
                            FilterChip(text: condition.rawValue, icon: "checkmark.seal") {
                                selectedCondition = nil
                            }
                        }
                        
                        if minPrice > 0 || maxPrice < 10000 {
                            FilterChip(text: "$\(Int(minPrice)) - $\(Int(maxPrice))", icon: "dollarsign.circle") {
                                minPrice = 0
                                maxPrice = 10000
                            }
                        }
                        
                        // Clear All
                        Button(action: clearFilters) {
                            Text("Clear All")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.error)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppColors.error.opacity(0.1))
                                .cornerRadius(AppRadius.full)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
                .padding(.bottom, AppSpacing.sm)
            }
            
            Divider()
            
            // Results
            if searchText.isEmpty && !hasActiveFilters {
                VStack(spacing: AppSpacing.lg) {
                    Spacer()
                    
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(AppColors.textTertiary)
                    
                    VStack(spacing: 8) {
                        Text("Search Marketplace")
                            .font(AppFonts.title2)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Find items by name, description, or category")
                            .font(AppFonts.callout)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                }
                .padding(AppSpacing.xl)
            } else if searchResults.isEmpty {
                VStack(spacing: AppSpacing.lg) {
                    Spacer()
                    
                    Image(systemName: "exclamationmark.magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(AppColors.textTertiary)
                    
                    VStack(spacing: 8) {
                        Text("No Results Found")
                            .font(AppFonts.title2)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Try different keywords or filters")
                            .font(AppFonts.callout)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(AppSpacing.xl)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: AppSpacing.md),
                        GridItem(.flexible(), spacing: AppSpacing.md)
                    ], spacing: AppSpacing.md) {
                        ForEach(searchResults) { item in
                            NavigationLink(destination: MarketplaceDetailView(item: item, marketplaceViewModel: marketplaceViewModel)) {
                                MarketplaceItemCard(
                                    item: item,
                                    distance: nil
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(AppSpacing.md)
                }
            }
        }
        .background(AppColors.background)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingFilters) {
            FiltersView(
                selectedCategory: $selectedCategory,
                selectedCondition: $selectedCondition,
                minPrice: $minPrice,
                maxPrice: $maxPrice
            )
        }
    }
    
    func clearFilters() {
        selectedCategory = nil
        selectedCondition = nil
        minPrice = 0
        maxPrice = 10000
    }
}

//// MARK: - Filter Chip
//
//struct FilterChip: View {
//    let text: String
//    let icon: String
//    let onRemove: () -> Void
//    
//    var body: some View {
//        HStack(spacing: 6) {
//            Image(systemName: icon)
//                .font(.system(size: 12, weight: .semibold))
//            Text(text)
//                .font(AppFonts.caption)
//            
//            Button(action: onRemove) {
//                Image(systemName: "xmark")
//                    .font(.system(size: 10, weight: .bold))
//            }
//        }
//        .padding(.horizontal, 12)
//        .padding(.vertical, 6)
//        .background(AppColors.primary.opacity(0.15))
//        .foregroundColor(AppColors.primary)
//        .cornerRadius(AppRadius.full)
//    }
//}

// MARK: - Filters View

struct FiltersView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedCategory: MarketplaceCategory?
    @Binding var selectedCondition: ItemCondition?
    @Binding var minPrice: Double
    @Binding var maxPrice: Double
    
    var body: some View {
        NavigationView {
            Form {
                // Category Section
                Section(header: Text("Category")) {
                    Picker("Category", selection: $selectedCategory) {
                        Text("All Categories").tag(nil as MarketplaceCategory?)
                        ForEach(MarketplaceCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category as MarketplaceCategory?)
                        }
                    }
                }
                
                // Condition Section
                Section(header: Text("Condition")) {
                    Picker("Condition", selection: $selectedCondition) {
                        Text("Any Condition").tag(nil as ItemCondition?)
                        ForEach(ItemCondition.allCases, id: \.self) { condition in
                            Text(condition.rawValue).tag(condition as ItemCondition?)
                        }
                    }
                }
                
                // Price Range Section
                Section(header: Text("Price Range")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Min:")
                            Spacer()
                            Text("$\(Int(minPrice))")
                                .foregroundColor(AppColors.primary)
                        }
                        
                        Slider(value: $minPrice, in: 0...maxPrice, step: 10)
                        
                        HStack {
                            Text("Max:")
                            Spacer()
                            Text("$\(Int(maxPrice))")
                                .foregroundColor(AppColors.primary)
                        }
                        
                        Slider(value: $maxPrice, in: minPrice...10000, step: 10)
                    }
                }
                
                // Reset Section
                Section {
                    Button(action: {
                        selectedCategory = nil
                        selectedCondition = nil
                        minPrice = 0
                        maxPrice = 10000
                    }) {
                        HStack {
                            Spacer()
                            Text("Reset Filters")
                                .foregroundColor(AppColors.error)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
