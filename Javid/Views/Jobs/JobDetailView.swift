import SwiftUI
import MapKit
import FirebaseAuth

struct JobDetailView: View {
    let job: Job
    
    @State private var region: MKCoordinateRegion
    @State private var showingApplySheet = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var hasApplied = false
    
    @StateObject private var jobViewModel = JobViewModel()
    @StateObject private var applicationVM = JobApplicationViewModel()
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var isSaved: Bool {
        guard let jobId = job.id else { return false }
        return jobViewModel.isSaved(jobId: jobId)
    }
    
    init(job: Job) {
        self.job = job
        _region = State(initialValue: MKCoordinateRegion(
            center: job.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    VStack(spacing: AppSpacing.lg) {
                        // Quick Info
                        quickInfoSection
                        
                        Divider()
                            .padding(.horizontal, AppSpacing.md)
                        
                        // Description
                        descriptionSection
                        
                        Divider()
                            .padding(.horizontal, AppSpacing.md)
                        
                        // Requirements
                        requirementsSection
                        
                        Divider()
                            .padding(.horizontal, AppSpacing.md)
                        
                        // Responsibilities
                        responsibilitiesSection
                        
                        if !job.benefits.isEmpty {
                            Divider()
                                .padding(.horizontal, AppSpacing.md)
                            
                            benefitsSection
                        }
                        
                        if !job.skills.isEmpty {
                            Divider()
                                .padding(.horizontal, AppSpacing.md)
                            
                            skillsSection
                        }
                        
                        Divider()
                            .padding(.horizontal, AppSpacing.md)
                        
                        // Location
                        locationSection
                        
                        // Apply Button Space
                        Spacer()
                            .frame(height: 100)
                    }
                    .padding(.vertical, AppSpacing.lg)
                }
            }
            .background(AppColors.background)
            .ignoresSafeArea(edges: .top)
            
            // Back Button
            Button(action: {
                dismiss()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.top, 50)
            .padding(.leading, AppSpacing.md)
        }
        .navigationBarHidden(true)
        .overlay(alignment: .bottom) {
            // Apply Button
            applyButtonSection
        }
        .sheet(isPresented: $showingApplySheet) {
            ApplyToJobView(job: job)
                .environmentObject(applicationVM)
        }
        .alert("Message", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            if let jobId = job.id {
                jobViewModel.incrementViewCount(for: jobId)
                checkIfApplied()
            }
            jobViewModel.fetchUserSavedJobs()
        }
    }
    
    // MARK: - Header Section
    var headerSection: some View {
        VStack(spacing: AppSpacing.lg) {
            // Company Logo
            if let logoURL = job.companyLogo, let url = URL(string: logoURL) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } placeholder: {
                    ZStack {
                        AppColors.surface
                        ProgressView()
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                ZStack {
                    Color(hex: job.category.color).opacity(0.2)
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: job.category.color))
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            VStack(spacing: 8) {
                // Job Title
                Text(job.title)
                    .font(AppFonts.title1)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                // Company
                HStack(spacing: 6) {
                    Text(job.company)
                        .font(AppFonts.title3)
                        .foregroundColor(AppColors.textSecondary)
                    
                    if job.employerVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.success)
                    }
                }
                
                // Location
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.primary)
                    Text("\(job.city), \(job.country)")
                        .font(AppFonts.callout)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.lg)
        .background(AppColors.surface)
    }
    
    // MARK: - Quick Info Section
    var quickInfoSection: some View {
        HStack(spacing: AppSpacing.md) {
            QuickInfoCard(
                icon: job.jobType.icon,
                title: job.jobType.rawValue,
                color: AppColors.primary
            )
            
            QuickInfoCard(
                icon: job.workMode.icon,
                title: job.workMode.rawValue,
                color: AppColors.accent
            )
            
            QuickInfoCard(
                icon: "star.fill",
                title: job.experienceLevel.rawValue,
                color: AppColors.success
            )
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - Description Section
    var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "About the Job", icon: "doc.text.fill")
            
            Text(job.description)
                .font(AppFonts.body)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Requirements Section
    var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Requirements", icon: "checkmark.circle.fill")
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(job.requirements, id: \.self) { requirement in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.primary)
                            .padding(.top, 4)
                        
                        Text(requirement)
                            .font(AppFonts.callout)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Responsibilities Section
    var responsibilitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Responsibilities", icon: "list.bullet.circle.fill")
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(job.responsibilities, id: \.self) { responsibility in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundColor(AppColors.primary)
                            .padding(.top, 8)
                        
                        Text(responsibility)
                            .font(AppFonts.callout)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Benefits Section
    var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Benefits", icon: "gift.fill")
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(job.benefits, id: \.self) { benefit in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.accent)
                            .padding(.top, 6)
                        
                        Text(benefit)
                            .font(AppFonts.callout)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Skills Section
    var skillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Required Skills", icon: "wrench.and.screwdriver.fill")
            
            FlowLayout(spacing: 8) {
                ForEach(job.skills, id: \.self) { skill in
                    Text(skill)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColors.primary.opacity(0.1))
                        .cornerRadius(AppRadius.full)
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Location Section
    var locationSection: some View {
        VStack(spacing: AppSpacing.sm) {
            SectionHeader(title: "Location", icon: "map.fill")
            
            VStack(spacing: AppSpacing.sm) {
                // Map
                Map(coordinateRegion: $region, annotationItems: [job]) { job in
                    MapMarker(coordinate: job.coordinate, tint: .red)
                }
                .frame(height: 200)
                .cornerRadius(AppRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(colorScheme == .dark ? AppColors.border.opacity(0.2) : Color.clear, lineWidth: 1)
                )
                
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(AppColors.primary)
                    Text(job.location)
                        .font(AppFonts.callout)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Apply Button Section
    var applyButtonSection: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: AppSpacing.md) {
                // Save Button
                Button(action: toggleSave) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSaved ? AppColors.accent : AppColors.textPrimary)
                        .frame(width: 56, height: 56)
                        .background(AppColors.surface)
                        .cornerRadius(AppRadius.md)
                        .shadow(color: AppShadow.small, radius: 4, x: 0, y: 2)
                }
                
                // Apply Button
                Button(action: applyToJob) {
                    HStack {
                        if hasApplied {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Applied")
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Apply Now")
                        }
                    }
                    .font(AppFonts.bodyBold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(hasApplied ? AppColors.success : AppColors.primary)
                    .cornerRadius(AppRadius.md)
                    .shadow(color: hasApplied ? AppColors.success.opacity(0.3) : AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(hasApplied)
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
        }
    }
    
    // MARK: - Helper Functions
    func checkIfApplied() {
        guard let jobId = job.id else { return }
        applicationVM.hasApplied(to: jobId) { applied in
            hasApplied = applied
        }
    }
    
    func applyToJob() {
        guard Auth.auth().currentUser != nil else {
            alertMessage = "Please sign in to apply for jobs"
            showingAlert = true
            return
        }
        
        showingApplySheet = true
    }
    
    func toggleSave() {
        guard let jobId = job.id else { return }
        
        guard Auth.auth().currentUser != nil else {
            alertMessage = "Please sign in to save jobs"
            showingAlert = true
            return
        }
        
        jobViewModel.toggleSave(jobId: jobId) { success, message in
            if !success {
                alertMessage = message
                showingAlert = true
            }
        }
    }
}

// MARK: - Quick Info Card
struct QuickInfoCard: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
    }
}

// MARK: - Flow Layout (for skills)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize
        var positions: [CGPoint]
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var size: CGSize = .zero
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let subviewSize = subview.sizeThatFits(.unspecified)
                
                if currentX + subviewSize.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, subviewSize.height)
                currentX += subviewSize.width + spacing
                size.width = max(size.width, currentX - spacing)
            }
            
            size.height = currentY + lineHeight
            self.size = size
            self.positions = positions
        }
    }
}
