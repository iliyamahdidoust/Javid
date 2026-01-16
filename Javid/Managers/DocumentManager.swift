import Foundation
import UIKit
import PDFKit

class DocumentManager {
    static let shared = DocumentManager()
    
    private let cloudName = "javid"
    private let uploadPreset = "job_documents"
    
    private init() {}
    
    // MARK: - Upload PDF Document (Resume, etc.)
    func uploadDocument(_ documentURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        guard let documentData = try? Data(contentsOf: documentURL) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read document"])))
            return
        }
        
        // Create upload URL
        let uploadURL = URL(string: "https://api.cloudinary.com/v1_1/\(cloudName)/raw/upload")!
        
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
        
        // Add document data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"document.pdf\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(documentData)
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
    
    // MARK: - Create PDF from Text (for cover letter)
    func createPDFFromText(_ text: String, title: String = "Cover Letter") -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "Javid Jobs",
            kCGPDFContextTitle: title
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(title).pdf")
        
        do {
            try renderer.writePDF(to: tempURL) { context in
                context.beginPage()
                
                let textRect = CGRect(x: 72, y: 72, width: pageWidth - 144, height: pageHeight - 144)
                
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .left
                paragraphStyle.lineSpacing = 5
                
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .paragraphStyle: paragraphStyle
                ]
                
                text.draw(in: textRect, withAttributes: attributes)
            }
            
            return tempURL
        } catch {
            print("❌ Error creating PDF: \(error)")
            return nil
        }
    }
    
    // MARK: - Validate Document
    func validateDocument(_ url: URL) -> (isValid: Bool, error: String?) {
        // Check file size (max 10MB)
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                let maxSize: Int64 = 10 * 1024 * 1024 // 10MB
                if fileSize > maxSize {
                    return (false, "File size exceeds 10MB limit")
                }
            }
        } catch {
            return (false, "Unable to read file")
        }
        
        // Check file extension
        let validExtensions = ["pdf", "doc", "docx"]
        let fileExtension = url.pathExtension.lowercased()
        
        if !validExtensions.contains(fileExtension) {
            return (false, "Only PDF, DOC, and DOCX files are supported")
        }
        
        return (true, nil)
    }
    
    // MARK: - Delete Document
    func deleteDocument(url: String, completion: @escaping (Bool) -> Void) {
        // Extract public ID from URL
        guard let publicId = extractPublicId(from: url) else {
            completion(false)
            return
        }
        
        print("Document deletion requested for: \(publicId)")
        // For production, implement server-side deletion
        completion(true)
    }
    
    private func extractPublicId(from url: String) -> String? {
        let components = url.components(separatedBy: "/")
        guard let uploadIndex = components.firstIndex(of: "upload"),
              uploadIndex + 2 < components.count else {
            return nil
        }
        
        let filename = components[uploadIndex + 2]
        return filename.components(separatedBy: ".").first
    }
}
