import SwiftUI
import CoreLocation

struct JobsBrowseView: View {
    @EnvironmentObject var jobViewModel: JobViewModel
    @StateObject private var locationManager = LocationManager()
    
    @State private var selectedCategory: JobCategory? = nil
    @State private var isRefreshing = false
    @State private var showingSearch = false
    
    @Environment(\.colorScheme) var colorScheme
    
    var filteredJobs: [Job] {
        if let category = selectedCategory {
            return jobViewModel.jobs.filter { $0.category == category }
        }
        return jobViewModel.jobs
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: AppSpacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Find Jobs")
                                .font(AppFonts.largeTitle)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("\(jobViewModel.jobs.count) opportunities available")
                                .font(AppFonts.callout)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Search Button
                        Button(action: {
                            showingSearch = true
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(AppColors.primary)
                                .frame(width: 44, height: 44)
                                .background(AppColors.surface)
                                .cornerRadius(AppRadius.full)
                                .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.small, radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.sm)
                    
                    // Categories
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            JobCategoryChip(
                                category: nil,
                                isSelected: selectedCategory == nil
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedCategory = nil
                                }
                            }
                            
                            ForEach(JobCategory.allCases, id: \.self) { category in
                                JobCategoryChip(
                                    category: category,
                                    isSelected: selectedCategory == category
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
                .padding(.bottom, AppSpacing.md)
                .background(AppColors.surface)
                
                // Jobs List
                if jobViewModel.isLoading && jobViewModel.jobs.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(0..<5, id: \.self) { _ in
                                SkeletonJobCard()
                            }
                        }
                        .padding(AppSpacing.md)
                    }
                } else if filteredJobs.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            // Refresh indicator
                            if isRefreshing {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Text("Refreshing...")
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                    Spacer()
                                }
                                .padding(.vertical, AppSpacing.sm)
                            }
                            
                            ForEach(Array(filteredJobs.enumerated()), id: \.element.id) { index, job in
                                NavigationLink(destination: JobDetailView(job: job)) {
                                    JobCard(
                                        job: job,
                                        distance: locationManager.location != nil ? jobViewModel.getDistance(to: job) : nil
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .onAppear {
                                    if index == filteredJobs.count - 3 {
                                        jobViewModel.loadMoreJobs()
                                    }
                                }
                            }
                            
                            // Loading more indicator
                            if jobViewModel.isLoadingMore {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Text("Loading more...")
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                    Spacer()
                                }
                                .padding(.vertical, AppSpacing.md)
                            }
                            
                            // End message
                            if !jobViewModel.hasMoreData && !jobViewModel.jobs.isEmpty {
                                Text("You've reached the end")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.textTertiary)
                                    .padding(.vertical, AppSpacing.lg)
                            }
                        }
                        .padding(AppSpacing.md)
                    }
                    .refreshable {
                        await refreshData()
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingSearch) {
            JobSearchView()
                .environmentObject(jobViewModel)
        }
        .onAppear {
            requestLocationIfNeeded()
        }
    }
    
    // MARK: - Empty State
    var emptyStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            
            Image(systemName: "briefcase")
                .font(.system(size: 80))
                .foregroundColor(AppColors.textTertiary)
            
            VStack(spacing: 8) {
                Text("No Jobs Found")
                    .font(AppFonts.title2)
                    .foregroundColor(AppColors.textPrimary)
                
                if selectedCategory != nil {
                    Text("Try selecting a different category")
                        .font(AppFonts.callout)
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    Text("Check back soon for new opportunities")
                        .font(AppFonts.callout)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Helper Functions
    func requestLocationIfNeeded() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestPermission()
        } else if locationManager.authorizationStatus == .authorizedWhenInUse ||
                  locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startUpdating()
        }
    }
    
    @MainActor
    func refreshData() async {
        isRefreshing = true
        jobViewModel.refreshJobs()
        
        while jobViewModel.isLoading {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        isRefreshing = false
    }
}

// MARK: - Job Category Chip
struct JobCategoryChip: View {
    let category: JobCategory?
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let category = category {
                    Image(systemName: category.icon)
                        .font(.system(size: 14, weight: .semibold))
                } else {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 14, weight: .semibold))
                }
                
                Text(category?.rawValue ?? "All")
                    .font(AppFonts.callout)
                    .fontWeight(isSelected ? .semibold : .medium)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 10)
            .background(isSelected ? AppColors.primary : AppColors.surface)
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .cornerRadius(AppRadius.full)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.full)
                    .stroke(isSelected ? Color.clear : AppColors.border, lineWidth: 1.5)
            )
            .shadow(color: isSelected ? AppColors.primary.opacity(0.25) : (colorScheme == .dark ? Color.clear : AppShadow.small), radius: isSelected ? 6 : 2, x: 0, y: isSelected ? 3 : 1)
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Skeleton Job Card
struct SkeletonJobCard: View {
    @State private var isAnimating = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Company logo skeleton
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.surface.opacity(0.5))
                    .frame(width: 50, height: 50)
                
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.surface.opacity(0.5))
                        .frame(height: 16)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.surface.opacity(0.5))
                        .frame(width: 120, height: 12)
                }
            }
            
            RoundedRectangle(cornerRadius: 4)
                .fill(AppColors.surface.opacity(0.5))
                .frame(height: 14)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(AppColors.surface.opacity(0.5))
                .frame(width: 200, height: 12)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
        .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.small, radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.clear, Color.white.opacity(colorScheme == .dark ? 0.1 : 0.4), Color.clear]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: isAnimating ? 400 : -400)
        )
        .onAppear {
            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}
