import SwiftUI
import FirebaseFirestore

struct ModernBusinessCard: View {
    let business: Business
    var distance: Double?
    
    @State private var appeared = false
    @State private var liveRating: Double
    @State private var liveReviewCount: Int
    @Environment(\.colorScheme) var colorScheme
    
    init(business: Business, distance: Double? = nil) {
        self.business = business
        self.distance = distance
        _liveRating = State(initialValue: business.rating)
        _liveReviewCount = State(initialValue: business.reviewCount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image Section
            ZStack(alignment: .topTrailing) {
                if let firstPhotoURL = business.photoURLs.first,
                   let url = URL(string: firstPhotoURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                    } placeholder: {
                        ZStack {
                            AppColors.surface
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        .frame(height: 180)
                    }
                } else {
                    ZStack {
                        AppColors.surface
                        VStack(spacing: 8) {
                            Image(systemName: "building.2")
                                .font(.system(size: 40))
                                .foregroundColor(AppColors.textTertiary)
                            Text("No photo")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .frame(height: 180)
                }
                
                // Category Badge
                Text(business.category)
                    .font(AppFonts.captionBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.categoryColor(for: business.category))
                    .cornerRadius(AppRadius.sm)
                    .padding([.top, .trailing], AppSpacing.sm)
            }
            
            // Content Section
            VStack(alignment: .leading, spacing: 12) {
                // Title & Rating
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(business.name)
                            .font(AppFonts.title3)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.starYellow)
                            Text(String(format: "%.1f", liveRating))
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Text("(\(liveReviewCount))")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    
                    Spacer()
                }
                
                // Description
                Text(business.description)
                    .font(AppFonts.callout)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                
                // Location & Distance
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.primary)
                    
                    Text(business.city)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    if let distance = distance {
                        Text("•")
                            .foregroundColor(AppColors.textTertiary)
                        Text(String(format: "%.1f km", distance))
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
        }
        .background(AppColors.surface)
        .cornerRadius(AppRadius.lg)
        .shadow(color: colorScheme == .dark ? Color.clear : AppShadow.medium, radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(colorScheme == .dark ? AppColors.border.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                appeared = true
            }
            fetchLiveRating()
        }
        .onChange(of: business.rating) { newRating in
            liveRating = newRating
        }
        .onChange(of: business.reviewCount) { newCount in
            liveReviewCount = newCount
        }
    }
    
    // Fetch live rating from Firestore
    private func fetchLiveRating() {
        guard let businessId = business.id else { return }
        
        let db = Firestore.firestore()
        db.collection("reviews")
            .whereField("businessId", isEqualTo: businessId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching reviews: \(error)")
                    return
                }
                
                let reviews = snapshot?.documents.compactMap { doc -> Review? in
                    try? doc.data(as: Review.self)
                } ?? []
                
                if !reviews.isEmpty {
                    let total = reviews.reduce(0.0) { $0 + $1.rating }
                    DispatchQueue.main.async {
                        self.liveRating = total / Double(reviews.count)
                        self.liveReviewCount = reviews.count
                    }
                }
            }
    }
}
