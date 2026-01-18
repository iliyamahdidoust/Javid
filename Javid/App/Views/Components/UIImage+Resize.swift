import UIKit

extension UIImage {
    /// Resize image to fit within a maximum dimension while maintaining aspect ratio
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let size = self.size
        
        // If image is already small enough, return it
        if size.width <= maxDimension && size.height <= maxDimension {
            return self
        }
        
        // Calculate new size maintaining aspect ratio
        let aspectRatio = size.width / size.height
        var newSize: CGSize
        
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Resize image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }
}
