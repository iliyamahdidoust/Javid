import SwiftUI
import FirebaseAuth

struct JobsMainView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var jobViewModel = JobViewModel()
    @StateObject private var jobSeekerProfileVM = JobSeekerProfileViewModel()
    @StateObject private var employerProfileVM = EmployerProfileViewModel()
    @StateObject private var applicationVM = JobApplicationViewModel()
    @StateObject private var messagingVM = JobMessagingViewModel()
    
    @State private var selectedTab = 0 // 0: Browse, 1: Profile, 2: Applications, 3: Messages
    @State private var showingProfileSetup = false
    @State private var userRole: UserRole = .none
    @State private var isCheckingProfile = true // Track loading state
    
    @Environment(\.colorScheme) var colorScheme
    
    enum UserRole {
        case jobSeeker
        case employer
        case none
    }
    
    var body: some View {
        NavigationView {
            if authViewModel.isLoggedIn {
                if isCheckingProfile {
                    // Show loading while determining user role
                    VStack {
                        ProgressView("Loading...")
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.background)
                } else {
                    VStack(spacing: 0) {
                        // Custom Tab Bar
                        customTabBar
                        
                        // Content
                        TabView(selection: $selectedTab) {
                            // Tab 0: Browse Jobs
                            JobsBrowseView()
                                .environmentObject(jobViewModel)
                                .tag(0)
                            
                            // Tab 1: Profile
                            Group {
                                if userRole == .jobSeeker {
                                    JobSeekerProfileView()
                                        .environmentObject(jobSeekerProfileVM)
                                } else if userRole == .employer {
                                    EmployerProfileView()
                                        .environmentObject(employerProfileVM)
                                } else {
                                    // No profile - show setup
                                    ProfileSetupView(
                                        jobSeekerProfileVM: jobSeekerProfileVM,
                                        employerProfileVM: employerProfileVM,
                                        onRoleSelected: { role in
                                            userRole = role
                                            // Fetch data based on role
                                            if role == .jobSeeker {
                                                applicationVM.fetchUserApplications()
                                            }
                                        }
                                    )
                                }
                            }
                            .tag(1)
                            
                            // Tab 2: Applications/Posted Jobs
                            Group {
                                if userRole == .jobSeeker {
                                    JobApplicationsView()
                                        .environmentObject(applicationVM)
                                        .environmentObject(jobViewModel)
                                } else if userRole == .employer {
                                    EmployerJobsView()
                                        .environmentObject(jobViewModel)
                                        .environmentObject(applicationVM)
                                        .environmentObject(employerProfileVM)
                                } else {
                                    // No profile - redirect to setup
                                    VStack(spacing: 20) {
                                        Image(systemName: "person.badge.plus")
                                            .font(.system(size: 60))
                                            .foregroundColor(AppColors.primary)
                                        
                                        Text("Complete Your Profile")
                                            .font(AppFonts.title2)
                                        
                                        Text("Please set up your profile first")
                                            .font(AppFonts.body)
                                            .foregroundColor(AppColors.textSecondary)
                                        
                                        Button("Go to Profile") {
                                            selectedTab = 1
                                        }
                                        .font(AppFonts.bodyBold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 30)
                                        .padding(.vertical, 12)
                                        .background(AppColors.primary)
                                        .cornerRadius(AppRadius.md)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(AppColors.background)
                                }
                            }
                            .tag(2)
                            
                            // Tab 3: Messages
                            JobMessagesView()
                                .environmentObject(messagingVM)
                                .tag(3)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    }
                    .navigationBarHidden(true)
                }
            } else {
                // Not logged in
                JobsGuestView()
            }
        }
        .onAppear {
            if authViewModel.isLoggedIn {
                checkUserProfile()
            }
        }
        .onChange(of: authViewModel.isLoggedIn) { isLoggedIn in
            if isLoggedIn {
                checkUserProfile()
            }
        }
    }
    
    // MARK: - Custom Tab Bar
    var customTabBar: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "briefcase.fill",
                title: "Jobs",
                isSelected: selectedTab == 0
            ) {
                selectedTab = 0
            }
            
            TabBarButton(
                icon: "person.fill",
                title: "Profile",
                isSelected: selectedTab == 1
            ) {
                selectedTab = 1
            }
            
            TabBarButton(
                icon: userRole == .employer ? "list.bullet.clipboard" : "doc.text.fill",
                title: userRole == .employer ? "Posted Jobs" : "Applications",
                isSelected: selectedTab == 2
            ) {
                selectedTab = 2
            }
            
            TabBarButton(
                icon: "message.fill",
                title: "Messages",
                isSelected: selectedTab == 3,
                badge: messagingVM.getTotalUnreadCount()
            ) {
                selectedTab = 3
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.surface)
        .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.small, radius: 4, x: 0, y: -2)
    }
    
    // MARK: - Check User Profile
    func checkUserProfile() {
        isCheckingProfile = true
        
        // Fetch profiles - call directly on the StateObject
        jobSeekerProfileVM.fetchProfile()
        employerProfileVM.fetchEmployerProfile()
        
        // Check profiles after fetch completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if jobSeekerProfileVM.profile != nil {
                userRole = .jobSeeker
                applicationVM.fetchUserApplications()
                print("✅ User role: Job Seeker")
            } else if employerProfileVM.employerProfile != nil {
                userRole = .employer
                print("✅ User role: Employer")
            } else {
                userRole = .none
                print("⚠️ No profile found - showing setup")
            }
            
            // Fetch common data
            jobViewModel.fetchJobs()
            messagingVM.fetchConversations()
            
            isCheckingProfile = false
        }
    }
}

// MARK: - Profile Setup View
struct ProfileSetupView: View {
    @ObservedObject var jobSeekerProfileVM: JobSeekerProfileViewModel
    @ObservedObject var employerProfileVM: EmployerProfileViewModel
    let onRoleSelected: (JobsMainView.UserRole) -> Void
    
    @State private var showingJobSeekerSetup = false
    @State private var showingEmployerSetup = false
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 12) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(AppColors.primary)
                
                Text("Complete Your Profile")
                    .font(AppFonts.title2)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Choose how you want to use the jobs platform")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            
            VStack(spacing: 16) {
                // Job Seeker Option
                Button(action: { showingJobSeekerSetup = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "person.fill")
                                    .font(.title2)
                                Text("I'm Looking for a Job")
                                    .font(AppFonts.bodyBold)
                            }
                            
                            Text("Create your profile, upload resume, and apply to jobs")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding()
                    .background(AppColors.surface)
                    .cornerRadius(AppRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(AppColors.primary.opacity(0.3), lineWidth: 1)
                    )
                }
                .foregroundColor(AppColors.textPrimary)
                
                // Employer Option
                Button(action: { showingEmployerSetup = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "building.2.fill")
                                    .font(.title2)
                                Text("I'm Hiring")
                                    .font(AppFonts.bodyBold)
                            }
                            
                            Text("Post jobs, review applications, and find talent")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding()
                    .background(AppColors.surface)
                    .cornerRadius(AppRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(AppColors.primary.opacity(0.3), lineWidth: 1)
                    )
                }
                .foregroundColor(AppColors.textPrimary)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingJobSeekerSetup) {
            NavigationView {
                EditJobSeekerProfileView()
                    .environmentObject(jobSeekerProfileVM)
            }
            .onDisappear {
                if jobSeekerProfileVM.profile != nil {
                    onRoleSelected(.jobSeeker)
                }
            }
        }
        .sheet(isPresented: $showingEmployerSetup) {
            NavigationView {
                EditEmployerProfileView(viewModel: employerProfileVM)
            }
            .onDisappear {
                if employerProfileVM.employerProfile != nil {
                    onRoleSelected(.employer)
                }
            }
        }
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    var badge: Int? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? AppColors.primary : AppColors.textSecondary)
                    
                    if let badge = badge, badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppColors.error)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -8)
                    }
                }
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? AppColors.primary : AppColors.textSecondary)
                
                if isSelected {
                    Rectangle()
                        .fill(AppColors.primary)
                        .frame(height: 2)
                        .frame(maxWidth: 40)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 2)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Jobs Guest View (Not Logged In)
struct JobsGuestView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingLoginSheet = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "briefcase.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(AppColors.primary)
            
            VStack(spacing: 12) {
                Text("Find Your Dream Job")
                    .font(AppFonts.title1)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Sign in to browse thousands of job opportunities,\napply with one click, and track your applications")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 16) {
                Button(action: {
                    showingLoginSheet = true
                }) {
                    Text("Sign In / Sign Up")
                        .font(AppFonts.bodyBold)
                        .foregroundColor(.white)
                        .frame(maxWidth: 300)
                        .padding()
                        .background(AppColors.primary)
                        .cornerRadius(AppRadius.md)
                }
                
                Text("or")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textTertiary)
                
                // Browse jobs as guest
                NavigationLink(destination: JobsBrowseView().environmentObject(JobViewModel())) {
                    Text("Browse Jobs as Guest")
                        .font(AppFonts.callout)
                        .foregroundColor(AppColors.primary)
                }
            }
            
            Spacer()
        }
        .navigationTitle("Jobs")
        .sheet(isPresented: $showingLoginSheet) {
            AuthView(authViewModel: authViewModel)
        }
    }
}
