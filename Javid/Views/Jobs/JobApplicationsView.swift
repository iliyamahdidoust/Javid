import SwiftUI

struct JobApplicationsView: View {
    @EnvironmentObject var applicationVM: JobApplicationViewModel
    @EnvironmentObject var jobViewModel: JobViewModel
    
    @State private var selectedFilter: ApplicationStatus? = nil
    
    @Environment(\.colorScheme) var colorScheme
    
    var filteredApplications: [JobApplication] {
        if let filter = selectedFilter {
            return applicationVM.applications.filter { $0.status == filter }
        }
        return applicationVM.applications
    }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: AppSpacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("My Applications")
                                .font(AppFonts.largeTitle)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("\(applicationVM.applications.count) applications")
                                .font(AppFonts.callout)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.sm)
                    
                    // Stats
                    statsSection
                    
                    // Status Filters
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            StatusFilterChip(
                                status: nil,
                                count: applicationVM.applications.count,
                                isSelected: selectedFilter == nil
                            ) {
                                selectedFilter = nil
                            }
                            
                            ForEach(ApplicationStatus.allCases, id: \.self) { status in
                                let count = applicationVM.applications.filter { $0.status == status }.count
                                if count > 0 {
                                    StatusFilterChip(
                                        status: status,
                                        count: count,
                                        isSelected: selectedFilter == status
                                    ) {
                                        selectedFilter = status
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }
                }
                .padding(.bottom, AppSpacing.md)
                .background(AppColors.surface)
                
                // Applications List
                if applicationVM.isLoading {
                    ProgressView("Loading applications...")
                        .padding()
                } else if filteredApplications.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(filteredApplications) { application in
                                NavigationLink(destination: ApplicationDetailView(application: application)) {
                                    ApplicationCard(application: application)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(AppSpacing.md)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if applicationVM.applications.isEmpty {
                applicationVM.fetchUserApplications()
            }
        }
    }
    
    // MARK: - Stats Section
    var statsSection: some View {
        let stats = applicationVM.getApplicationStats()
        
        return HStack(spacing: AppSpacing.sm) {
            StatCard(title: "Total", value: "\(stats.total)", color: AppColors.primary)
            StatCard(title: "Pending", value: "\(stats.pending)", color: AppColors.accent)
            StatCard(title: "Reviewed", value: "\(stats.reviewed)", color: AppColors.success)
            StatCard(title: "Rejected", value: "\(stats.rejected)", color: AppColors.error)
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - Empty State
    var emptyStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textTertiary)
            
            VStack(spacing: 8) {
                Text(selectedFilter == nil ? "No Applications Yet" : "No \(selectedFilter!.rawValue) Applications")
                    .font(AppFonts.title2)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(selectedFilter == nil ? "Start applying to jobs to see them here" : "Try a different filter")
                    .font(AppFonts.callout)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
    }
}

// MARK: - Status Filter Chip
struct StatusFilterChip: View {
    let status: ApplicationStatus?
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let status = status {
                    Image(systemName: status.icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(status?.rawValue ?? "All")
                    .font(AppFonts.callout)
                    .fontWeight(isSelected ? .semibold : .medium)
                
                Text("(\(count))")
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 10)
            .background(isSelected ? Color(hex: status?.color ?? "3B82F6") : AppColors.surface)
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .cornerRadius(AppRadius.full)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.full)
                    .stroke(isSelected ? Color.clear : AppColors.border, lineWidth: 1.5)
            )
        }
    }
}

// MARK: - Application Card
struct ApplicationCard: View {
    let application: JobApplication
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(application.jobTitle)
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                    
                    Text(application.company)
                        .font(AppFonts.callout)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                // Status Badge
                HStack(spacing: 4) {
                    Image(systemName: application.status.icon)
                        .font(.system(size: 10))
                    Text(application.status.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: application.status.color))
                .cornerRadius(AppRadius.sm)
            }
            
            Divider()
            
            // Footer
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text("Applied \(application.appliedAt.timeAgo())")
                        .font(AppFonts.caption)
                }
                .foregroundColor(AppColors.textTertiary)
                
                Spacer()
                
                if application.viewedByEmployer {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 10))
                        Text("Viewed")
                            .font(AppFonts.caption)
                    }
                    .foregroundColor(AppColors.success)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
        .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.small, radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(colorScheme == .dark ? AppColors.border.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Application Detail View (Simple)
struct ApplicationDetailView: View {
    let application: JobApplication
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Job Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(application.jobTitle)
                        .font(AppFonts.title2)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(application.company)
                        .font(AppFonts.title3)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                // Status
                HStack {
                    Image(systemName: application.status.icon)
                    Text(application.status.rawValue)
                        .font(AppFonts.bodyBold)
                }
                .foregroundColor(Color(hex: application.status.color))
                
                Divider()
                
                // Cover Letter
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cover Letter")
                        .font(AppFonts.title3)
                    Text(application.coverLetter)
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                // Resume
                Button(action: {
                    if let url = URL(string: application.resumeURL) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "doc.fill")
                        Text("View Resume")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                    .foregroundColor(AppColors.primary)
                    .padding()
                    .background(AppColors.surface)
                    .cornerRadius(AppRadius.md)
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.background)
        .navigationTitle("Application Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
