import SwiftUI

// MARK: - App Colors
struct AppColors {
    // Primary Colors with Gradients
    static let primary = Color(hex: "3B82F6")
    static let primaryDark = Color(hex: "2563EB")
    static let primaryLight = Color(hex: "60A5FA")
    
    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "3B82F6"), Color(hex: "2563EB")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Accent Colors
    static let accent = Color(hex: "F59E0B")
    static let accentLight = Color(hex: "FCD34D")
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "F59E0B"), Color(hex: "F97316")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // Semantic Colors
    static let success = Color(hex: "10B981")
    static let successLight = Color(hex: "34D399")
    static let warning = Color(hex: "F59E0B")
    static let error = Color(hex: "EF4444")
    static let info = Color(hex: "3B82F6")
    
    // Adaptive Background Colors
    static var background: Color {
        Color(UIColor.systemGroupedBackground)
    }
    
    static var surface: Color {
        Color(UIColor.secondarySystemGroupedBackground)
    }
    
    static var surfaceElevated: Color {
        Color(UIColor.tertiarySystemGroupedBackground)
    }
    
    // Adaptive Text Colors
    static var textPrimary: Color {
        Color(UIColor.label)
    }
    
    static var textSecondary: Color {
        Color(UIColor.secondaryLabel)
    }
    
    static var textTertiary: Color {
        Color(UIColor.tertiaryLabel)
    }
    
    // Adaptive Border & Shadow
    static var border: Color {
        Color(UIColor.separator)
    }
    
    static var borderLight: Color {
        Color(UIColor.separator).opacity(0.5)
    }
    
    static func cardShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }
    
    static func cardShadowHover(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.12)
    }
    
    // Rating (always same)
    static let starYellow = Color(hex: "FBBF24")
    
    // Category Colors (always vibrant)
    static let categoryColors: [String: Color] = [
        "Restaurant": Color(hex: "EF4444"),
        "Store": Color(hex: "3B82F6"),
        "Services": Color(hex: "8B5CF6"),
        "Doctor": Color(hex: "10B981"),
        "Lawyer": Color(hex: "F59E0B"),
        "Salon": Color(hex: "EC4899")
    ]
    
    static func categoryColor(for category: String) -> Color {
        categoryColors[category] ?? primary
    }
    
    static func categoryGradient(for category: String) -> LinearGradient {
        let color = categoryColors[category] ?? primary
        return LinearGradient(
            colors: [color, color.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - App Fonts
struct AppFonts {
    // Headers with SF Pro Rounded
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 22, weight: .bold, design: .rounded)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
    
    // Body
    static let body = Font.system(size: 17, weight: .regular)
    static let bodyBold = Font.system(size: 17, weight: .semibold)
    static let callout = Font.system(size: 16, weight: .regular)
    
    // Small
    static let caption = Font.system(size: 12, weight: .regular)
    static let captionBold = Font.system(size: 12, weight: .semibold)
    static let footnote = Font.system(size: 13, weight: .regular)
}

// MARK: - App Spacing
struct AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - App Radius
struct AppRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 999
}

// MARK: - App Shadows
struct AppShadow {
    static let small = Color.black.opacity(0.05)
    static let medium = Color.black.opacity(0.08)
    static let large = Color.black.opacity(0.12)
}

// MARK: - Animation Presets
struct AppAnimation {
    static let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let smooth = Animation.easeInOut(duration: 0.3)
    static let quick = Animation.easeOut(duration: 0.2)
}

// MARK: - Color Extension (Hex support)
//extension Color {
//    init(hex: String) {
//        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
//        var int: UInt64 = 0
//        Scanner(string: hex).scanHexInt64(&int)
//        let a, r, g, b: UInt64
//        switch hex.count {
//        case 3:
//            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
//        case 6:
//            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
//        case 8:
//            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
//        default:
//            (a, r, g, b) = (1, 1, 1, 0)
//        }
//
//        self.init(
//            .sRGB,
//            red: Double(r) / 255,
//            green: Double(g) / 255,
//            blue: Double(b) / 255,
//            opacity: Double(a) / 255
//        )
//    }
//}

// MARK: - View Extensions for Modern Effects
extension View {
    func modernCard(colorScheme: ColorScheme) -> some View {
        self
            .background(AppColors.surface)
            .cornerRadius(AppRadius.lg)
            .shadow(
                color: AppColors.cardShadow(for: colorScheme),
                radius: 8,
                x: 0,
                y: 4
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(
                        colorScheme == .dark ? AppColors.border.opacity(0.2) : Color.clear,
                        lineWidth: 1
                    )
            )
    }
    
    func modernButton(isPressed: Bool = false) -> some View {
        self
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(AppAnimation.quick, value: isPressed)
    }
    
    func shimmer(isAnimating: Binding<Bool>) -> some View {
        self.modifier(ShimmerEffect(isAnimating: isAnimating))
    }
}

// MARK: - Shimmer Effect
struct ShimmerEffect: ViewModifier {
    @Binding var isAnimating: Bool
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: phase)
                    .animation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: phase
                    )
            )
            .onAppear {
                if isAnimating {
                    phase = 300
                }
            }
    }
}
