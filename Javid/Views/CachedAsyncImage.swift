import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else if isLoading {
                placeholder()
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        let urlString = url.absoluteString
        
        // Check cache first
        if let cachedImage = ImageCacheManager.shared.getImage(forKey: urlString) {
            self.image = cachedImage
            return
        }
        
        // Download if not cached
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let data = data, let downloadedImage = UIImage(data: data) {
                    // Save to cache
                    ImageCacheManager.shared.setImage(downloadedImage, forKey: urlString)
                    self.image = downloadedImage
                }
            }
        }.resume()
    }
}
