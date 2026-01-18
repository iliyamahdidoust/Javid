import SwiftUI
import CoreLocation

struct SearchView: View {
    @ObservedObject var businessViewModel: BusinessViewModel
    @EnvironmentObject var favoriteViewModel: FavoriteViewModel  // ✅ Added this
    @StateObject private var locationManager = LocationManager()
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @FocusState private var isSearchFocused: Bool
    
    @Environment(\.colorScheme) var colorScheme
    
    let categories = ["All", "Restaurant", "Store", "Services", "Doctor", "Lawyer", "Salon"]
    
    var filteredBusinesses: [Business] {
        guard !searchText.isEmpty else { return [] }
        
        return businessViewModel.businesses.filter { business in
            let matchesSearch = business.name.localizedCaseInsensitiveContains(searchText) ||
                business.city.localizedCaseInsensitiveContains(searchText) ||
                business.description.localizedCaseInsensitiveContains(searchText) ||
                business.address.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == "All" || business.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Section
                    VStack(spacing: AppSpacing.md) {
                        // Title
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Search")
                                    .font(AppFonts.largeTitle)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("Find your favorite businesses")
                                    .font(AppFonts.callout)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.sm)
                        
                        // Search Bar
                        ModernSearchBar(text: $searchText, placeholder: "Search by name, city, or description...")
                            .padding(.horizontal, AppSpacing.md)
                            .focused($isSearchFocused)
                        
                        // Categories
                        if !searchText.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(categories, id: \.self) { category in
                                        CategoryChip(
                                            title: category,
                                            isSelected: selectedCategory == category,
                                            icon: categoryIcon(for: category)
                                        ) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                selectedCategory = category
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, AppSpacing.md)
                            }
                        }
                    }
                    .padding(.bottom, AppSpacing.md)
                    .background(AppColors.surface)
                    
                    // Content Area
                    if searchText.isEmpty {
                        // Empty State
                        VStack(spacing: AppSpacing.xl) {
                            Spacer()
                            
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 80, weight: .thin))
                                .foregroundColor(AppColors.textTertiary)
                            
                            VStack(spacing: 8) {
                                Text("Search for Businesses")
                                    .font(AppFonts.title2)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("Start typing to find restaurants, stores,\nservices, and more")
                                    .font(AppFonts.callout)
                                    .foregroundColor(AppColors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            // Quick suggestions
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Text("Try searching for:")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.textTertiary)
                                    .padding(.horizontal, AppSpacing.md)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        QuickSearchButton(text: "Restaurants") {
                                            searchText = "Restaurant"
                                        }
                                        QuickSearchButton(text: "Toronto") {
                                            searchText = "Toronto"
                                        }
                                        QuickSearchButton(text: "Doctor") {
                                            searchText = "Doctor"
                                        }
                                        QuickSearchButton(text: "Salon") {
                                            searchText = "Salon"
                                        }
                                    }
                                    .padding(.horizontal, AppSpacing.md)
                                }
                            }
                            .padding(.top, AppSpacing.lg)
                            
                            Spacer()
                        }
                    } else if filteredBusinesses.isEmpty {
                        // No Results State
                        VStack(spacing: AppSpacing.lg) {
                            Spacer()
                            
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 80, weight: .thin))
                                .foregroundColor(AppColors.textTertiary)
                            
                            VStack(spacing: 8) {
                                Text("No results found")
                                    .font(AppFonts.title2)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("Try different keywords or check your spelling")
                                    .font(AppFonts.callout)
                                    .foregroundColor(AppColors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Button(action: {
                                searchText = ""
                                selectedCategory = "All"
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Clear Search")
                                }
                                .font(AppFonts.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.primary)
                                .padding(.horizontal, AppSpacing.lg)
                                .padding(.vertical, AppSpacing.md)
                                .background(AppColors.primary.opacity(0.1))
                                .cornerRadius(AppRadius.full)
                            }
                            .padding(.top, AppSpacing.md)
                            
                            Spacer()
                        }
                    } else {
                        // Results List
                        VStack(spacing: 0) {
                            // Results count
                            HStack {
                                Text("\(filteredBusinesses.count) result\(filteredBusinesses.count == 1 ? "" : "s") found")
                                    .font(AppFonts.callout)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Spacer()
                                
                                if selectedCategory != "All" {
                                    Button(action: {
                                        selectedCategory = "All"
                                    }) {
                                        HStack(spacing: 4) {
                                            Text("Clear filter")
                                                .font(AppFonts.caption)
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 14))
                                        }
                                        .foregroundColor(AppColors.primary)
                                    }
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(AppColors.surface)
                            
                            ScrollView {
                                LazyVStack(spacing: AppSpacing.md) {
                                    ForEach(filteredBusinesses) { business in
                                        NavigationLink(destination: BusinessDetailView(business: business)) {
                                            ModernBusinessCard(
                                                business: business,
                                                distance: locationManager.location != nil ? businessViewModel.getDistance(to: business) : nil
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(AppSpacing.md)
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                // Auto-focus on search bar when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isSearchFocused = true
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    func categoryIcon(for category: String) -> String? {
        switch category {
        case "All": return "square.grid.2x2"
        case "Restaurant": return "fork.knife"
        case "Store": return "cart"
        case "Services": return "wrench.and.screwdriver"
        case "Doctor": return "cross.case"
        case "Lawyer": return "briefcase"
        case "Salon": return "scissors"
        default: return nil
        }
    }
}

// MARK: - Quick Search Button
struct QuickSearchButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                Text(text)
                    .font(AppFonts.callout)
                    .fontWeight(.medium)
            }
            .foregroundColor(AppColors.textPrimary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 10)
            .background(AppColors.surface)
            .cornerRadius(AppRadius.full)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.full)
                    .stroke(AppColors.border, lineWidth: 1.5)
            )
        }
    }
}
