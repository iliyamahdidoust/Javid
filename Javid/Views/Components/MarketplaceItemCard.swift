import SwiftUI

struct MarketplaceItemCard: View {
    let item: MarketplaceItem
    var distance: Double?
    var showActions: Bool = false
    
    @State private var appeared = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image Section
            ZStack(alignment: .topTrailing) {
                if let firstPhotoURL = item.photoURLs.first,
                   let url = URL(string: firstPhotoURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 140)
                            .clipped()
                    } placeholder: {
                        ZStack {
                            AppColors.surface
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        .frame(height: 140)
                    }
                } else {
                    ZStack {
                        AppColors.surface
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 30))
                                .foregroundColor(AppColors.textTertiary)
                            Text("No photo")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .frame(height: 140)
                }
                
                // Sold Badge
                if item.isSold {
                    Text("SOLD")
                        .font(AppFonts.captionBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .cornerRadius(AppRadius.sm)
                        .padding([.top, .trailing], AppSpacing.sm)
                }
            }
            
            // Content Section
            VStack(alignment: .leading, spacing: 6) {
                // Price
                Text(item.formattedPrice)
                    .font(AppFonts.title3)
                    .foregroundColor(AppColors.primary)
                    .lineLimit(1)
                
                // Title
                Text(item.title)
                    .font(AppFonts.callout)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .frame(height: 36, alignment: .top)
                
                // Location & Distance
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text(item.location)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                    
                    if let distance = distance {
                        Text("• \(String(format: "%.1f km", distance))")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                
                // Condition badge
                Text(item.condition.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppColors.surface.opacity(0.5))
                    .cornerRadius(4)
            }
            .padding(AppSpacing.sm)
            .background(AppColors.surface)
        }
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
        .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.small, radius: 4, x: 0, y: 2)
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
