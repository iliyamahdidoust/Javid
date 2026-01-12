import SwiftUI

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let icon: String?
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    init(title: String, isSelected: Bool, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                
                Text(title)
                    .font(AppFonts.callout)
                    .fontWeight(isSelected ? .semibold : .medium)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 10)
            .background(isSelected ? AppColors.primary : AppColors.surface)
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .cornerRadius(AppRadius.full)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.full)
                    .stroke(isSelected ? Color.clear : AppColors.border, lineWidth: 1.5)
            )
            .shadow(color: isSelected ? AppColors.primary.opacity(0.25) : (colorScheme == .dark ? Color.clear : AppShadow.small), radius: isSelected ? 6 : 2, x: 0, y: isSelected ? 3 : 1)
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
