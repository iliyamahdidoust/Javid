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
        guard !isLoading else { return }
        
        let urlString = url.absoluteString
        
        // Check cache first
        if let cachedImage = ImageCacheManager.shared.getImage(forKey: urlString) {
            self.image = cachedImage
            return
        }
        
        isLoading = true
        
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache.shared
        config.requestCachePolicy = .returnCacheDataElseLoad
        
        let session = URLSession(configuration: config)
        
        session.dataTask(with: url) { data, response, error in
            defer {
                DispatchQueue.main.async {
                    isLoading = false
                }
            }
            
            guard let data = data,
                  let downloadedImage = UIImage(data: data) else {
                return
            }
            
            // Resize image if too large to save memory
            let maxDimension: CGFloat = 800
            let resizedImage = downloadedImage.resized(toMaxDimension: maxDimension)
            
            // Compress with REDUCED quality
            let compressedImage: UIImage
            if let compressed = resizedImage.jpegData(compressionQuality: 0.5),  // Reduced from 0.7
               let finalImage = UIImage(data: compressed) {
                compressedImage = finalImage
            } else {
                compressedImage = resizedImage
            }
            
            DispatchQueue.main.async {
                ImageCacheManager.shared.setImage(compressedImage, forKey: urlString)
                self.image = compressedImage
            }
        }.resume()
    }
}
