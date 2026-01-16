import SwiftUI

struct JobCard: View {
    let job: Job
    var distance: Double?
    
    @State private var appeared = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Company Logo & Name
            HStack(spacing: 12) {
                // Company Logo
                if let logoURL = job.companyLogo, let url = URL(string: logoURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } placeholder: {
                        ZStack {
                            AppColors.surface
                            Image(systemName: "building.2")
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                } else {
                    ZStack {
                        Color(hex: job.category.color).opacity(0.15)
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: job.category.color))
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.company)
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    if job.employerVerified {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.success)
                            Text("Verified")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.success)
                        }
                    }
                }
                
                Spacer()
                
                // Category Badge
                Text(job.category.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: job.category.color))
                    .cornerRadius(AppRadius.sm)
            }
            
            // Job Title
            Text(job.title)
                .font(AppFonts.title3)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(2)
            
            // Job Details
            VStack(alignment: .leading, spacing: 8) {
                // Salary
                if let salaryMin = job.salaryMin, let salaryMax = job.salaryMax {
                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.success)
                        Text(job.salaryRange)
                            .font(AppFonts.callout)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                // Job Type & Work Mode
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: job.jobType.icon)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.primary)
                        Text(job.jobType.rawValue)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Text("•")
                        .foregroundColor(AppColors.textTertiary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: job.workMode.icon)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.primary)
                        Text(job.workMode.rawValue)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                // Location & Distance
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.primary)
                    
                    Text(job.city)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    if let distance = distance {
                        Text("•")
                            .foregroundColor(AppColors.textTertiary)
                        Text(String(format: "%.1f km", distance))
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            
            Divider()
            
            // Footer: Posted date & Applications
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary)
                    Text(job.createdAt.timeAgo())
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                
                Spacer()
                
                if job.applicationCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textTertiary)
                        Text("\(job.applicationCount) applicants")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
        .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.medium, radius: 6, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(colorScheme == .dark ? AppColors.border.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                appeared = true
            }
        }
    }
}
