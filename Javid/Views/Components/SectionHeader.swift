import SwiftUI

struct SectionHeader: View {
    let title: String
    let icon: String?
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(title: String, icon: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }
                
                Text(title)
                    .font(AppFonts.title3)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Spacer()
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(AppFonts.callout)
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }
}
