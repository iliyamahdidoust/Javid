import SwiftUI

struct HeroImageHeader: View {
    let photoURLs: [String]
    @State private var currentPage = 0
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if !photoURLs.isEmpty {
                TabView(selection: $currentPage) {
                    ForEach(Array(photoURLs.enumerated()), id: \.offset) { index, urlString in
                        CachedAsyncImage(url: URL(string: urlString)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 350)
                                .clipped()
                        } placeholder: {
                            ZStack {
                                AppColors.surface
                                ProgressView()
                            }
                            .frame(height: 350)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 350)
                
                // Custom Page Indicator
                if photoURLs.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<photoURLs.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? Color.white : Color.white.opacity(0.5))
                                .frame(width: 8, height: 8)
                                .scaleEffect(currentPage == index ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(AppRadius.full)
                    .padding(.bottom, AppSpacing.md)
                }
            } else {
                ZStack {
                    AppColors.surface
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(AppColors.textTertiary)
                        Text("No photos available")
                            .font(AppFonts.callout)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .frame(height: 350)
            }
        }
    }
}
