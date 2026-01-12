import Foundation
import UIKit

class CloudinaryManager {
    private let cloudName = "javid"
    private let uploadPreset = "business_images"
    
    static let shared = CloudinaryManager()
    
    private init() {}
    
    func uploadImage(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        // Convert image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])))
            return
        }
        
        // Create upload URL
        let uploadURL = URL(string: "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload")!
        
        // Create request
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        
        // Create boundary
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create body
        var body = Data()
        
        // Add upload preset
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(uploadPreset)\r\n".data(using: .utf8)!)
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Send request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let secureUrl = json["secure_url"] as? String {
                    DispatchQueue.main.async {
                        completion(.success(secureUrl))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    func deleteImage(url: String, completion: @escaping (Bool) -> Void) {
        // Extract public ID from URL
        guard let publicId = extractPublicId(from: url) else {
            completion(false)
            return
        }
        
        // For deletion, you need to use Admin API with authentication
        // For now, we'll just return success
        // In production, you should implement server-side deletion
        print("Image deletion requested for: \(publicId)")
        completion(true)
    }
    
    private func extractPublicId(from url: String) -> String? {
        // Extract public ID from Cloudinary URL
        // Example: https://res.cloudinary.com/demo/image/upload/v1234567890/sample.jpg
        // Public ID: sample
        
        let components = url.components(separatedBy: "/")
        guard let uploadIndex = components.firstIndex(of: "upload"),
              uploadIndex + 2 < components.count else {
            return nil
        }
        
        let filename = components[uploadIndex + 2]
        return filename.components(separatedBy: ".").first
    }
}
