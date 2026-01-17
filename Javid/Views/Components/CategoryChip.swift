import SwiftUI

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let icon: String?
    let action: () -> Void
    
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme
    
    init(title: String, isSelected: Bool, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                }
                
                Text(title)
                    .font(AppFonts.callout)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            }
            .padding(.horizontal, AppSpacing.md + 2)
            .padding(.vertical, 11)
            .background(
                Group {
                    if isSelected {
                        AppColors.primaryGradient
                    } else {
                        AppColors.surface
                            .overlay(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.05)
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
                                ? AppColors.border.opacity(0.3)
                                : AppColors.border),
                        lineWidth: 1.5
                    )
            )
            .shadow(
                color: isSelected
                    ? AppColors.primary.opacity(0.3)
                    : (colorScheme == .dark ? Color.clear : AppShadow.small),
                radius: isSelected ? 8 : 3,
                x: 0,
                y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(CategoryChipButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(AppAnimation.spring, value: isSelected)
    }
}

// Custom Button Style for Category Chips
struct CategoryChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(AppAnimation.quick, value: configuration.isPressed)
    }
}
