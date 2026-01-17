import SwiftUI

struct MarketplaceCategoryChip: View {
    let category: MarketplaceCategory?
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme
    
    var categoryColor: Color {
        if let category = category {
            return Color(hex: category.color)
        }
        return AppColors.primary
    }
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: 7) {
                // Icon with background circle
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 24, height: 24)
                    }
                    
                    Image(systemName: category?.icon ?? "square.grid.2x2")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? .white : categoryColor)
                }
                
                Text(category?.rawValue ?? "All")
                    .font(AppFonts.callout)
                    .fontWeight(isSelected ? .bold : .semibold)
                    .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            }
            .padding(.horizontal, AppSpacing.md + 2)
            .padding(.vertical, 11)
            .background(
                Group {
                    if isSelected {
                        if let category = category {
                            LinearGradient(
                                colors: [
                                    Color(hex: category.color),
                                    Color(hex: category.color).opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            AppColors.primaryGradient
                        }
                    } else {
                        AppColors.surface
                            .overlay(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.04)
                                    : Color.clear
                            )
                    }
                }
            )
            .cornerRadius(AppRadius.full)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.full)
                    .stroke(
                        isSelected
                            ? Color.clear
                            : (colorScheme == .dark
                                ? AppColors.border.opacity(0.25)
                                : categoryColor.opacity(0.2)),
                        lineWidth: 1.5
                    )
            )
            .shadow(
                color: isSelected
                    ? categoryColor.opacity(0.35)
                    : (colorScheme == .dark ? Color.clear : AppShadow.small),
                radius: isSelected ? 8 : 3,
                x: 0,
                y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(MarketplaceCategoryButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(AppAnimation.spring, value: isSelected)
    }
}

struct MarketplaceCategoryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(AppAnimation.quick, value: configuration.isPressed)
    }
}
