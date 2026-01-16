import SwiftUI

struct JobSearchView: View {
    @EnvironmentObject var jobViewModel: JobViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var searchText = ""
    @State private var selectedCategory: JobCategory? = nil
    @State private var selectedJobType: JobType? = nil
    @State private var selectedWorkMode: WorkMode? = nil
    @State private var selectedExperience: ExperienceLevel? = nil
    @State private var minSalary: Double = 0
    @State private var maxSalary: Double = 200000
    @State private var location = ""
    @State private var showingFilters = false
    
    var searchResults: [Job] {
        jobViewModel.searchJobs(
            query: searchText,
            category: selectedCategory,
            jobType: selectedJobType,
            workMode: selectedWorkMode,
            experienceLevel: selectedExperience,
            salaryMin: minSalary > 0 ? minSalary : nil,
            salaryMax: maxSalary < 200000 ? maxSalary : nil,
            location: location
        )
    }
    
    var hasActiveFilters: Bool {
        selectedCategory != nil || selectedJobType != nil || selectedWorkMode != nil ||
        selectedExperience != nil || minSalary > 0 || maxSalary < 200000 || !location.isEmpty
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                ModernSearchBar(text: $searchText, placeholder: "Search by title, company, or skills...")
                    .padding(AppSpacing.md)
                
                // Active Filters
                if hasActiveFilters {
                    activeFiltersSection
                }
                
                // Filters button
                Button(action: {
                    showingFilters = true
                }) {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Filters")
                            .font(AppFonts.callout)
                            .fontWeight(.semibold)
                        Spacer()
                        if hasActiveFilters {
                            Circle()
                                .fill(AppColors.primary)
                                .frame(width: 8, height: 8)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .foregroundColor(AppColors.primary)
                    .padding()
                    .background(AppColors.surface)
                    .cornerRadius(AppRadius.md)
                    .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.small, radius: 4, x: 0, y: 2)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)
                
                Divider()
                
                // Results Count
                HStack {
                    Text("\(searchResults.count) job\(searchResults.count == 1 ? "" : "s") found")
                        .font(AppFonts.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.surface)
                
                // Results
                if searchResults.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(searchResults) { job in
                                NavigationLink(destination: JobDetailView(job: job)) {
                                    JobCard(job: job)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(AppSpacing.md)
                    }
                }
            }
            .background(AppColors.background)
            .navigationTitle("Search Jobs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingFilters) {
                JobFiltersView(
                    selectedCategory: $selectedCategory,
                    selectedJobType: $selectedJobType,
                    selectedWorkMode: $selectedWorkMode,
                    selectedExperience: $selectedExperience,
                    minSalary: $minSalary,
                    maxSalary: $maxSalary,
                    location: $location
                )
            }
        }
    }
    
    // MARK: - Active Filters Section
    var activeFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let category = selectedCategory {
                    FilterChip(text: category.rawValue, icon: category.icon) {
                        selectedCategory = nil
                    }
                }
                
                if let jobType = selectedJobType {
                    FilterChip(text: jobType.rawValue, icon: jobType.icon) {
                        selectedJobType = nil
                    }
                }
                
                if let workMode = selectedWorkMode {
                    FilterChip(text: workMode.rawValue, icon: workMode.icon) {
                        selectedWorkMode = nil
                    }
                }
                
                if let experience = selectedExperience {
                    FilterChip(text: experience.rawValue, icon: "star") {
                        selectedExperience = nil
                    }
                }
                
                if minSalary > 0 || maxSalary < 200000 {
                    FilterChip(text: "$\(Int(minSalary))k - $\(Int(maxSalary))k", icon: "dollarsign.circle") {
                        minSalary = 0
                        maxSalary = 200000
                    }
                }
                
                if !location.isEmpty {
                    FilterChip(text: location, icon: "location") {
                        location = ""
                    }
                }
                
                // Clear All
                if hasActiveFilters {
                    Button(action: clearAllFilters) {
                        Text("Clear All")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.error)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppColors.error.opacity(0.1))
                            .cornerRadius(AppRadius.full)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
        .padding(.bottom, AppSpacing.sm)
    }
    
    // MARK: - Empty State
    var emptyStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textTertiary)
            
            VStack(spacing: 8) {
                Text("No Jobs Found")
                    .font(AppFonts.title2)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Try adjusting your search or filters")
                    .font(AppFonts.callout)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Helper Functions
    func clearAllFilters() {
        selectedCategory = nil
        selectedJobType = nil
        selectedWorkMode = nil
        selectedExperience = nil
        minSalary = 0
        maxSalary = 200000
        location = ""
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let text: String
    let icon: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(AppFonts.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppColors.primary.opacity(0.15))
        .foregroundColor(AppColors.primary)
        .cornerRadius(AppRadius.full)
    }
}

// MARK: - Job Filters View
struct JobFiltersView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedCategory: JobCategory?
    @Binding var selectedJobType: JobType?
    @Binding var selectedWorkMode: WorkMode?
    @Binding var selectedExperience: ExperienceLevel?
    @Binding var minSalary: Double
    @Binding var maxSalary: Double
    @Binding var location: String
    
    var body: some View {
        NavigationView {
            Form {
                // Category
                Section(header: Text("Category")) {
                    Picker("Category", selection: $selectedCategory) {
                        Text("All Categories").tag(nil as JobCategory?)
                        ForEach(JobCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category as JobCategory?)
                        }
                    }
                }
                
                // Job Type
                Section(header: Text("Job Type")) {
                    Picker("Job Type", selection: $selectedJobType) {
                        Text("All Types").tag(nil as JobType?)
                        ForEach(JobType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.rawValue)
                            }
                            .tag(type as JobType?)
                        }
                    }
                }
                
                // Work Mode
                Section(header: Text("Work Mode")) {
                    Picker("Work Mode", selection: $selectedWorkMode) {
                        Text("All Modes").tag(nil as WorkMode?)
                        ForEach(WorkMode.allCases, id: \.self) { mode in
                            HStack {
                                Image(systemName: mode.icon)
                                Text(mode.rawValue)
                            }
                            .tag(mode as WorkMode?)
                        }
                    }
                }
                
                // Experience Level
                Section(header: Text("Experience Level")) {
                    Picker("Experience", selection: $selectedExperience) {
                        Text("All Levels").tag(nil as ExperienceLevel?)
                        ForEach(ExperienceLevel.allCases, id: \.self) { level in
                            Text("\(level.rawValue) (\(level.yearsRange))").tag(level as ExperienceLevel?)
                        }
                    }
                }
                
                // Salary Range
                Section(header: Text("Salary Range (Annual)")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Min:")
                            Spacer()
                            Text("$\(Int(minSalary))k")
                                .foregroundColor(AppColors.primary)
                        }
                        Slider(value: $minSalary, in: 0...maxSalary, step: 5000)
                        
                        HStack {
                            Text("Max:")
                            Spacer()
                            Text("$\(Int(maxSalary))k")
                                .foregroundColor(AppColors.primary)
                        }
                        Slider(value: $maxSalary, in: minSalary...200000, step: 5000)
                    }
                }
                
                // Location
                Section(header: Text("Location")) {
                    TextField("City or Country", text: $location)
                }
                
                // Reset
                Section {
                    Button(action: resetFilters) {
                        HStack {
                            Spacer()
                            Text("Reset All Filters")
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
                    Button("Apply") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    func resetFilters() {
        selectedCategory = nil
        selectedJobType = nil
        selectedWorkMode = nil
        selectedExperience = nil
        minSalary = 0
        maxSalary = 200000
        location = ""
    }
}
