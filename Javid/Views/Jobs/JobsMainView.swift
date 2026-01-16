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
    @State private var userRole: UserRole = .jobSeeker
    
    @Environment(\.colorScheme) var colorScheme
    
    enum UserRole {
        case jobSeeker
        case employer
        case none
    }
    
    var body: some View {
        NavigationView {
            if authViewModel.isLoggedIn {
                VStack(spacing: 0) {
                    // Custom Tab Bar
                    customTabBar
                    
                    // Content
                    TabView(selection: $selectedTab) {
                        JobsBrowseView()
                            .environmentObject(jobViewModel)
                            .tag(0)
                        
                        if userRole == .jobSeeker {
                            JobSeekerProfileView()
                                .environmentObject(jobSeekerProfileVM)
                                .tag(1)
                            
                            JobApplicationsView()
                                .environmentObject(applicationVM)
                                .environmentObject(jobViewModel)
                                .tag(2)
                        } else if userRole == .employer {
                            EmployerProfileView()
                                .environmentObject(employerProfileVM)
                                .tag(1)
                            
                            EmployerJobsView()
                                .environmentObject(jobViewModel)
                                .environmentObject(applicationVM)
                                .tag(2)
                        }
                        
                        JobMessagesView()
                            .environmentObject(messagingVM)
                            .tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
                .navigationBarHidden(true)
                .onAppear {
                    checkUserProfile()
                }
            } else {
                // Not logged in
                JobsGuestView()
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
        // Check if user has job seeker profile
        jobSeekerProfileVM.checkIfProfileExists { hasJobSeekerProfile in
            if hasJobSeekerProfile {
                userRole = .jobSeeker
                jobSeekerProfileVM.fetchProfile()
                applicationVM.fetchUserApplications()
            } else {
                // Check if user has employer profile
                employerProfileVM.checkIfProfileExists { hasEmployerProfile in
                    if hasEmployerProfile {
                        userRole = .employer
                        employerProfileVM.fetchProfile()
                    } else {
                        // No profile, show setup
                        userRole = .none
                        showingProfileSetup = true
                    }
                }
            }
        }
        
        // Fetch common data
        jobViewModel.fetchJobs()
        messagingVM.fetchConversations()
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
