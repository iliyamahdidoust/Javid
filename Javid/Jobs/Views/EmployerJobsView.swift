import SwiftUI

struct EmployerJobsView: View {
    @EnvironmentObject var jobViewModel: JobViewModel
    @EnvironmentObject var applicationVM: JobApplicationViewModel
    @EnvironmentObject var employerProfileVM: EmployerProfileViewModel
    
    @State private var showingPostJob = false
    @State private var selectedJob: Job?
    
    @Environment(\.colorScheme) var colorScheme
    
    var employerJobs: [Job] {
        jobViewModel.getEmployerJobs()
    }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: AppSpacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("My Posted Jobs")
                                .font(AppFonts.largeTitle)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("\(employerJobs.count) active jobs")
                                .font(AppFonts.callout)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showingPostJob = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(AppColors.primary)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.sm)
                }
                .padding(.bottom, AppSpacing.md)
                .background(AppColors.surface)
                
                // Jobs List
                if jobViewModel.isLoading {
                    ProgressView("Loading jobs...")
                        .padding()
                } else if employerJobs.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(employerJobs) { job in
                                Button(action: {
                                    selectedJob = job
                                }) {
                                    EmployerJobCard(job: job)
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
        .sheet(isPresented: $showingPostJob) {
            PostJobView()
                .environmentObject(jobViewModel)
                .environmentObject(employerProfileVM)
        }
        .sheet(item: $selectedJob) { job in
            EmployerJobDetailView(job: job)
                .environmentObject(jobViewModel)
                .environmentObject(applicationVM)
        }
        .onAppear {
            if employerJobs.isEmpty {
                jobViewModel.fetchJobs()
            }
        }
    }
    
    // MARK: - Empty State
    var emptyStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            
            Image(systemName: "briefcase.circle")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textTertiary)
            
            VStack(spacing: 8) {
                Text("No Jobs Posted Yet")
                    .font(AppFonts.title2)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Start hiring by posting your first job")
                    .font(AppFonts.callout)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Button(action: {
                showingPostJob = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Post a Job")
                }
                .font(AppFonts.bodyBold)
                .foregroundColor(.white)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.primary)
                .cornerRadius(AppRadius.md)
            }
            
            Spacer()
        }
    }
}

// MARK: - Employer Job Card
struct EmployerJobCard: View {
    let job: Job
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(job.title)
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: job.jobType.icon)
                                .font(.system(size: 10))
                            Text(job.jobType.rawValue)
                                .font(AppFonts.caption)
                        }
                        
                        Text("•")
                        
                        HStack(spacing: 4) {
                            Image(systemName: job.workMode.icon)
                                .font(.system(size: 10))
                            Text(job.workMode.rawValue)
                                .font(AppFonts.caption)
                        }
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                if job.isActive {
                    Text("Active")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.success)
                        .cornerRadius(AppRadius.sm)
                } else {
                    Text("Inactive")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.textTertiary)
                        .cornerRadius(AppRadius.sm)
                }
            }
            
            Divider()
            
            HStack {
                HStack(spacing: 8) {
                    EmployerStatBadge(icon: "person.2.fill", value: "\(job.applicationCount)", color: AppColors.primary)
                    EmployerStatBadge(icon: "eye.fill", value: "\(job.viewCount)", color: AppColors.accent)
                    EmployerStatBadge(icon: "bookmark.fill", value: "\(job.savedCount)", color: AppColors.success)
                }
                
                Spacer()
                
                Text(job.createdAt.timeAgo())
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textTertiary)
                
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

// MARK: - Employer Stat Badge (Renamed to avoid conflicts)
struct EmployerStatBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(AppRadius.sm)
    }
}

// MARK: - Employer Job Detail View
struct EmployerJobDetailView: View {
    let job: Job
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jobViewModel: JobViewModel
    @EnvironmentObject var applicationVM: JobApplicationViewModel
    
    @State private var applications: [JobApplication] = []
    @State private var isLoadingApplications = false
    @State private var showingDeleteAlert = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Job Stats - Broken into simpler expression to avoid compiler timeout
                    jobStatsSection
                    
                    Divider()
                    
                    // Applications List
                    applicationsListSection
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.background)
            .navigationTitle(job.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive, action: {
                            showingDeleteAlert = true
                        }) {
                            Label("Delete Job", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Job", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteJob()
                }
            } message: {
                Text("Are you sure you want to delete this job posting?")
            }
            .alert("Message", isPresented: $showingAlert) {
                Button("OK") {
                    if alertMessage.contains("deleted") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadApplications()
            }
        }
    }
    
    // MARK: - Job Stats Section (Extracted to fix compiler timeout)
    private var jobStatsSection: some View {
        HStack(spacing: AppSpacing.sm) {
            StatCard(
                title: "Applications",
                value: "\(job.applicationCount)",
                color: AppColors.primary
            )
            StatCard(
                title: "Views",
                value: "\(job.viewCount)",
                color: AppColors.accent
            )
            StatCard(
                title: "Saved",
                value: "\(job.savedCount)",
                color: AppColors.success
            )
        }
    }
    
    // MARK: - Applications List Section
    private var applicationsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Applications (\(applications.count))")
                .font(AppFonts.title3)
                .foregroundColor(AppColors.textPrimary)
            
            if isLoadingApplications {
                ProgressView()
            } else if applications.isEmpty {
                Text("No applications yet")
                    .font(AppFonts.callout)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(applications) { application in
                    // FIXED: Using renamed component from ApplicationsListView
                    NavigationLink(destination: ApplicationDetailSheet(application: application)) {
                        ApplicationCardView(application: application)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    func loadApplications() {
        guard let jobId = job.id else { return }
        isLoadingApplications = true
        
        applicationVM.fetchApplicationsForJob(jobId: jobId) { apps in
            applications = apps
            isLoadingApplications = false
        }
    }
    
    func deleteJob() {
        jobViewModel.deleteJob(job) { success, message in
            alertMessage = message
            showingAlert = true
        }
    }
}
