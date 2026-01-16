import SwiftUI
import FirebaseAuth

struct JobSeekerProfileView: View {
    @EnvironmentObject var profileVM: JobSeekerProfileViewModel
    @State private var showingEditProfile = false
    @State private var showingCreateProfile = false
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            if profileVM.isLoading {
                ProgressView("Loading profile...")
            } else if profileVM.profile == nil {
                createProfilePrompt
            } else {
                profileContent
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditJobSeekerProfileView()
                .environmentObject(profileVM)
        }
        .sheet(isPresented: $showingCreateProfile) {
            CreateJobSeekerProfileView()
                .environmentObject(profileVM)
        }
        .onAppear {
            if profileVM.profile == nil {
                profileVM.fetchProfile()
            }
        }
    }
    
    // MARK: - Create Profile Prompt
    var createProfilePrompt: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(AppColors.primary)
            
            VStack(spacing: 12) {
                Text("Create Your Profile")
                    .font(AppFonts.title1)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Build a professional profile to apply for jobs and get noticed by employers")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: {
                showingCreateProfile = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Profile")
                }
                .font(AppFonts.bodyBold)
                .foregroundColor(.white)
                .frame(maxWidth: 300)
                .padding()
                .background(AppColors.primary)
                .cornerRadius(AppRadius.md)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Profile Content
    var profileContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                profileHeader
                
                VStack(spacing: AppSpacing.lg) {
                    // Profile Completeness
                    if let profile = profileVM.profile {
                        profileCompletenessCard(profile: profile)
                    }
                    
                    Divider()
                        .padding(.horizontal, AppSpacing.md)
                    
                    // About
                    if let profile = profileVM.profile, !profile.summary.isEmpty {
                        aboutSection(profile: profile)
                        
                        Divider()
                            .padding(.horizontal, AppSpacing.md)
                    }
                    
                    // Experience
                    if let profile = profileVM.profile, !profile.experience.isEmpty {
                        experienceSection(profile: profile)
                        
                        Divider()
                            .padding(.horizontal, AppSpacing.md)
                    }
                    
                    // Education
                    if let profile = profileVM.profile, !profile.education.isEmpty {
                        educationSection(profile: profile)
                        
                        Divider()
                            .padding(.horizontal, AppSpacing.md)
                    }
                    
                    // Skills
                    if let profile = profileVM.profile, !profile.skills.isEmpty {
                        skillsSection(profile: profile)
                        
                        Divider()
                            .padding(.horizontal, AppSpacing.md)
                    }
                    
                    // Certifications
                    if let profile = profileVM.profile, !profile.certifications.isEmpty {
                        certificationsSection(profile: profile)
                    }
                }
                .padding(.vertical, AppSpacing.lg)
            }
        }
    }
    
    // MARK: - Profile Header
    var profileHeader: some View {
        VStack(spacing: AppSpacing.md) {
            // Edit Button
            HStack {
                Spacer()
                Button(action: {
                    showingEditProfile = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("Edit Profile")
                    }
                    .font(AppFonts.callout)
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.primary.opacity(0.1))
                    .cornerRadius(AppRadius.full)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            
            // Profile Photo
            if let photoURL = profileVM.profile?.profilePhotoURL, let url = URL(string: photoURL) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } placeholder: {
                    profilePhotoPlaceholder
                }
            } else {
                profilePhotoPlaceholder
            }
            
            // Name & Headline
            VStack(spacing: 6) {
                Text(profileVM.profile?.fullName ?? "")
                    .font(AppFonts.title1)
                    .foregroundColor(AppColors.textPrimary)
                
                if let headline = profileVM.profile?.headline, !headline.isEmpty {
                    Text(headline)
                        .font(AppFonts.title3)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // Location
                if let profile = profileVM.profile, !profile.city.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                        Text("\(profile.city), \(profile.country)")
                            .font(AppFonts.callout)
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            
            // Contact Info
            if let profile = profileVM.profile {
                HStack(spacing: AppSpacing.lg) {
                    if !profile.email.isEmpty {
                        ContactButton(icon: "envelope.fill", text: "Email") {
                            if let url = URL(string: "mailto:\(profile.email)") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    
                    if !profile.phone.isEmpty {
                        ContactButton(icon: "phone.fill", text: "Call") {
                            if let url = URL(string: "tel:\(profile.phone)") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
        }
        .padding(.bottom, AppSpacing.md)
        .background(AppColors.surface)
    }
    
    var profilePhotoPlaceholder: some View {
        ZStack {
            Circle()
                .fill(AppColors.primary.opacity(0.15))
                .frame(width: 100, height: 100)
            
            Text(profileVM.profile?.fullName.prefix(1).uppercased() ?? "U")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(AppColors.primary)
        }
    }
    
    // MARK: - Profile Completeness Card
    func profileCompletenessCard(profile: JobSeekerProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile Strength")
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("\(profile.profileCompleteness)% Complete")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(AppColors.border, lineWidth: 6)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(profile.profileCompleteness) / 100)
                        .stroke(AppColors.primary, lineWidth: 6)
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(profile.profileCompleteness)%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.primary)
                }
            }
            
            if profile.profileCompleteness < 100 {
                Text("Complete your profile to increase your chances of getting hired")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - About Section
    func aboutSection(profile: JobSeekerProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "About", icon: "person.fill")
            
            Text(profile.summary)
                .font(AppFonts.body)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Experience Section
    func experienceSection(profile: JobSeekerProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Experience", icon: "briefcase.fill")
            
            VStack(spacing: AppSpacing.md) {
                ForEach(profile.experience.sorted(by: { exp1, exp2 in
                    if exp1.isCurrent { return true }
                    if exp2.isCurrent { return false }
                    return exp1.startDate > exp2.startDate
                })) { experience in
                    ExperienceCard(experience: experience)
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Education Section
    func educationSection(profile: JobSeekerProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Education", icon: "graduationcap.fill")
            
            VStack(spacing: AppSpacing.md) {
                ForEach(profile.education.sorted(by: { $0.startDate > $1.startDate })) { education in
                    EducationCard(education: education)
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Skills Section
    func skillsSection(profile: JobSeekerProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Skills", icon: "star.fill")
            
            FlowLayout(spacing: 8) {
                ForEach(profile.skills, id: \.self) { skill in
                    Text(skill)
                        .font(AppFonts.callout)
                        .foregroundColor(AppColors.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppColors.primary.opacity(0.1))
                        .cornerRadius(AppRadius.full)
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Certifications Section
    func certificationsSection(profile: JobSeekerProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Certifications", icon: "checkmark.seal.fill")
            
            VStack(spacing: AppSpacing.md) {
                ForEach(profile.certifications) { cert in
                    CertificationCard(certification: cert)
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
}

// MARK: - Contact Button
struct ContactButton: View {
    let icon: String
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(text)
                    .font(AppFonts.caption)
            }
            .foregroundColor(AppColors.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppColors.primary.opacity(0.1))
            .cornerRadius(AppRadius.full)
        }
    }
}

// MARK: - Experience Card
struct ExperienceCard: View {
    let experience: WorkExperience
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "briefcase.fill")
                    .foregroundColor(AppColors.primary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(experience.title)
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(experience.company)
                    .font(AppFonts.callout)
                    .foregroundColor(AppColors.textSecondary)
                
                Text(formatDateRange(start: experience.startDate, end: experience.endDate, isCurrent: experience.isCurrent))
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textTertiary)
                
                if !experience.description.isEmpty {
                    Text(experience.description)
                        .font(AppFonts.callout)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.top, 4)
                }
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
    }
    
    func formatDateRange(start: Date, end: Date?, isCurrent: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        let startStr = formatter.string(from: start)
        let endStr = isCurrent ? "Present" : (end != nil ? formatter.string(from: end!) : "")
        return "\(startStr) - \(endStr)"
    }
}

// MARK: - Education Card
struct EducationCard: View {
    let education: Education
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "graduationcap.fill")
                    .foregroundColor(AppColors.accent)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(education.degree)
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(education.fieldOfStudy)
                    .font(AppFonts.callout)
                    .foregroundColor(AppColors.textSecondary)
                
                Text(education.school)
                    .font(AppFonts.callout)
                    .foregroundColor(AppColors.textSecondary)
                
                Text(formatDateRange(start: education.startDate, end: education.endDate, isCurrent: education.isCurrent))
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
    }
    
    func formatDateRange(start: Date, end: Date?, isCurrent: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        let startStr = formatter.string(from: start)
        let endStr = isCurrent ? "Present" : (end != nil ? formatter.string(from: end!) : "")
        return "\(startStr) - \(endStr)"
    }
}

// MARK: - Certification Card
struct CertificationCard: View {
    let certification: Certification
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 24))
                .foregroundColor(AppColors.success)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(certification.name)
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(certification.issuingOrganization)
                    .font(AppFonts.callout)
                    .foregroundColor(AppColors.textSecondary)
                
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                Text("Issued: \(formatter.string(from: certification.issueDate))")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
    }
}

// MARK: - Create Profile View (Simple)
struct CreateJobSeekerProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var profileVM: JobSeekerProfileViewModel
    
    @State private var fullName = ""
    @State private var headline = ""
    @State private var phone = ""
    @State private var city = ""
    @State private var country = ""
    @State private var isSaving = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Full Name", text: $fullName)
                    TextField("Professional Headline", text: $headline)
                        .autocapitalization(.words)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section(header: Text("Location")) {
                    TextField("City", text: $city)
                    TextField("Country", text: $country)
                }
                
                Section {
                    Button(action: createProfile) {
                        if isSaving {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("Create Profile")
                                    .bold()
                                Spacer()
                            }
                        }
                    }
                    .disabled(isSaving || !isValid)
                }
            }
            .navigationTitle("Create Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
            }
            .alert("Message", isPresented: $showingAlert) {
                Button("OK") {
                    if alertMessage.contains("successfully") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    var isValid: Bool {
        !fullName.isEmpty && !phone.isEmpty
    }
    
    func createProfile() {
        guard let user = Auth.auth().currentUser else { return }
        
        isSaving = true
        
        let profile = JobSeekerProfile(
            userId: user.uid,
            fullName: fullName,
            email: user.email ?? "",
            phone: phone,
            headline: headline,
            summary: "",
            location: "",
            city: city,
            country: country
        )
        
        profileVM.createProfile(profile) { success, message in
            isSaving = false
            alertMessage = message
            showingAlert = true
        }
    }
}
