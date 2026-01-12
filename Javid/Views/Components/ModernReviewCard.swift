import SwiftUI

struct ModernReviewCard: View {
    let review: Review
    let userName: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Text(userName.prefix(1).uppercased())
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(userName)
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(review.rating) ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(index < Int(review.rating) ? AppColors.starYellow : AppColors.textTertiary)
                        }
                        
                        Text("•")
                            .foregroundColor(AppColors.textTertiary)
                            .font(AppFonts.caption)
                        
                        Text(review.createdAt.timeAgo())
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Spacer()
            }
            
            // Review Text
            Text(review.comment)
                .font(AppFonts.callout)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(4)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(colorScheme == .dark ? AppColors.border.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }
}

// Helper extension for time ago
extension Date {
    func timeAgo() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self, to: now)
        
        if let year = components.year, year > 0 {
            return "\(year)y ago"
        } else if let month = components.month, month > 0 {
            return "\(month)mo ago"
        } else if let day = components.day, day > 0 {
            return "\(day)d ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        } else {
            return "Just now"
        }
    }
}
