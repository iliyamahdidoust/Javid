import SwiftUI

struct MarketplaceCategoryChip: View {
    let category: MarketplaceCategory?
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let category = category {
                    Image(systemName: category.icon)
                        .font(.system(size: 14, weight: .semibold))
                } else {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 14, weight: .semibold))
                }
                
                Text(category?.rawValue ?? "All")
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
