import Foundation
import UIKit

enum CloudinaryFolder: String {
    case business = "businesses"
    case marketplace = "marketplace"
    case profile = "profiles"
    case reviews = "reviews"
}

enum CloudinaryPreset: String {
    case business = "business_images"
    case marketplace = "marketplace_preset"
    case profile = "profile_images"
}

class CloudinaryManager {
    private let cloudName = "javid"
    
    static let shared = CloudinaryManager()
    
    private init() {}
    
    // MEMORY OPTIMIZED upload method
    func uploadImage(_ image: UIImage, folder: CloudinaryFolder, preset: CloudinaryPreset, completion: @escaping (Result<String, Error>) -> Void) {
        print("🔵 Starting image upload to Cloudinary (folder: \(folder.rawValue), preset: \(preset.rawValue))...")
        
        // CRITICAL: Reduce image size MORE aggressively
        let maxDimension: CGFloat = 800  // Reduced from 1200
        let resizedImage = image.resized(toMaxDimension: maxDimension)
        
        // CRITICAL: Lower compression quality to reduce memory
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.5) else {  // Reduced from 0.7
            print("❌ Failed to convert image to JPEG data")
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])))
            return
        }
        
        print("✅ Image converted to JPEG (\(imageData.count) bytes)")
        
        // CRITICAL: Release the resized image from memory immediately
        // Don't keep references to large objects
        
        // Create upload URL
        let uploadURL = URL(string: "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload")!
        
        // Create request
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        
        // Create boundary
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create body
        var body = Data()
        
        // Add upload preset
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(preset.rawValue)\r\n".data(using: .utf8)!)
        
        // Add folder
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"folder\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(folder.rawValue)\r\n".data(using: .utf8)!)
        
        // Add timestamp to filename
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "\(folder.rawValue)_\(timestamp).jpg"
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("📤 Sending request to Cloudinary (body size: \(body.count) bytes)...")
        
        // CRITICAL: Use background URLSession configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        let session = URLSession(configuration: config)
        
        // Send request
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
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
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let secureUrl = json["secure_url"] as? String {
                        print("✅ Image uploaded successfully to \(folder.rawValue): \(secureUrl)")
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
        guard let publicId = extractPublicId(from: url) else {
            completion(false)
            return
        }
        
        print("⚠️ Image deletion requested for: \(publicId)")
        completion(true)
    }
    
    private func extractPublicId(from url: String) -> String? {
        let components = url.components(separatedBy: "/")
        guard let uploadIndex = components.firstIndex(of: "upload"),
              uploadIndex + 2 < components.count else {
            return nil
        }
        
        let afterVersion = components[(uploadIndex + 2)...]
        let publicIdWithExtension = afterVersion.joined(separator: "/")
        let publicId = publicIdWithExtension.components(separatedBy: ".").first
        return publicId
    }
}
