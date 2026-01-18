import SwiftUI

class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        // Configure cache for better memory management - REDUCED LIMITS
        cache.countLimit = 20  // Reduced from 50
        cache.totalCostLimit = 10 * 1024 * 1024  // Reduced to 10 MB from 30 MB
        
        // Clear cache on memory warning
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCacheOnMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func clearCacheOnMemoryWarning() {
        print("⚠️ Memory warning - clearing image cache")
        cache.removeAllObjects()
    }
    
    func getImage(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func setImage(_ image: UIImage, forKey key: String) {
        // Calculate cost (image size in bytes)
        let cost = image.jpegData(compressionQuality: 0.5)?.count ?? 0  // Reduced from 0.7
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    func removeImage(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}
