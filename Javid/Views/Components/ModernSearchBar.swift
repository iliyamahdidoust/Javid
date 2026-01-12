import SwiftUI

struct ModernSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isFocused ? AppColors.primary : AppColors.textSecondary)
                .font(.system(size: 18, weight: .semibold))
            
            TextField(placeholder, text: $text)
                .focused($isFocused)
                .font(AppFonts.body)
                .foregroundColor(AppColors.textPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textSecondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(AppColors.surface)
                .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.small, radius: isFocused ? 8 : 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(isFocused ? AppColors.primary : Color.clear, lineWidth: 2)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }
}
