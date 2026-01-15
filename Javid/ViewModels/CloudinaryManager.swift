import Foundation
import UIKit

class CloudinaryManager {
    private let cloudName = "javid"
    private let uploadPreset = "marketplace_preset" // Make sure this exists in Cloudinary
    
    static let shared = CloudinaryManager()
    
    private init() {}
    
    func uploadImage(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        print("🔵 Starting image upload to Cloudinary...")
        
        // Resize image before upload to save memory
        let maxDimension: CGFloat = 1200
        let resizedImage = image.resized(toMaxDimension: maxDimension)
        
        // Convert image to JPEG data with compression
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.7) else {
            print("❌ Failed to convert image to JPEG data")
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])))
            return
        }
        
        print("✅ Image converted to JPEG (\(imageData.count) bytes)")
        
        // Create upload URL
        let uploadURL = URL(string: "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload")!
        
        // Create request
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 60 // Increase timeout to 60 seconds
        
        // Create boundary
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create body
        var body = Data()
        
        // Add upload preset
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(uploadPreset)\r\n".data(using: .utf8)!)
        
        // Add folder (optional - organizes images in Cloudinary)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"folder\"\r\n\r\n".data(using: .utf8)!)
        body.append("marketplace\r\n".data(using: .utf8)!)
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("📤 Sending request to Cloudinary...")
        
        // Send request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 HTTP Status Code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    if let data = data, let errorResponse = String(data: data, encoding: .utf8) {
                        print("❌ Server error response: \(errorResponse)")
                    }
                }
            }
            
            guard let data = data else {
                print("❌ No data received from Cloudinary")
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                }
                return
            }
            
            // Print raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Response: \(responseString)")
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let secureUrl = json["secure_url"] as? String {
                        print("✅ Image uploaded successfully: \(secureUrl)")
                        DispatchQueue.main.async {
                            completion(.success(secureUrl))
                        }
                    } else if let error = json["error"] as? [String: Any],
                              let message = error["message"] as? String {
                        print("❌ Cloudinary error: \(message)")
                        DispatchQueue.main.async {
                            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cloudinary error: \(message)"])))
                        }
                    } else {
                        print("❌ Invalid response format")
                        DispatchQueue.main.async {
                            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                        }
                    }
                } else {
                    print("❌ Failed to parse JSON response")
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])))
                    }
                }
            } catch {
                print("❌ JSON parsing error: \(error.localizedDescription)")
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
        print("⚠️ Image deletion requested for: \(publicId)")
        print("⚠️ Note: Deletion requires server-side implementation with API credentials")
        completion(true)
    }
    
    private func extractPublicId(from url: String) -> String? {
        // Extract public ID from Cloudinary URL
        // Example: https://res.cloudinary.com/demo/image/upload/v1234567890/folder/sample.jpg
        // Public ID: folder/sample
        
        let components = url.components(separatedBy: "/")
        guard let uploadIndex = components.firstIndex(of: "upload"),
              uploadIndex + 2 < components.count else {
            return nil
        }
        
        // Get everything after version (v1234567890)
        let afterVersion = components[(uploadIndex + 2)...]
        let publicIdWithExtension = afterVersion.joined(separator: "/")
        
        // Remove file extension
        let publicId = publicIdWithExtension.components(separatedBy: ".").first
        return publicId
    }
}
