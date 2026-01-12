import SwiftUI

// MARK: - App Colors
struct AppColors {
    // Primary Colors
    static let primary = Color(hex: "3B82F6")
    static let primaryDark = Color(hex: "2563EB")
    static let primaryLight = Color(hex: "60A5FA")
    
    // Accent Colors
    static let accent = Color(hex: "F59E0B")
    static let accentLight = Color(hex: "FCD34D")
    
    // Semantic Colors
    static let success = Color(hex: "10B981")
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
    
    static var cardShadow: Color {
        Color.black.opacity(0.1)
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
}

// MARK: - App Fonts
struct AppFonts {
    // Headers
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

// MARK: - Color Extension (Hex support)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
