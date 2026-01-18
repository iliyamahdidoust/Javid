import SwiftUI

struct MarketplaceItemCard: View {
    let item: MarketplaceItem
    var distance: Double?
    var showActions: Bool = false
    
    @State private var appeared = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image Section - Square 1:1 ratio
            ZStack {
                if let firstPhotoURL = item.photoURLs.first,
                   let url = URL(string: firstPhotoURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(Color(white: colorScheme == .dark ? 0.2 : 0.95))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                ProgressView()
                            )
                    }
                } else {
                    Rectangle()
                        .fill(Color(white: colorScheme == .dark ? 0.2 : 0.95))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.5))
                        )
                }
                
                // SOLD overlay
                if item.isSold {
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                Text("SOLD")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        )
                }
            }
            
            // Text Section - Black/Dark background like Facebook
            VStack(alignment: .leading, spacing: 4) {
                // Price
                Text(item.formattedPrice)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                
                // Subject (Title) - dotted if too long
                Text(item.title)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                // City, distance
                HStack(spacing: 0) {
                    Text(item.location)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                    
                    if let distance = distance {
                        Text("(\(String(format: "%.1f", distance))km)")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.98))
        }
        .background(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.98))
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) {
                appeared = true
            }
        }
    }
}
