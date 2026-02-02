import Foundation
import SwiftUI

class ExportManager {
    
    /// Export data to CSV format
    static func exportToCSV<T>(data: [T], columns: [String], valueExtractor: (T) -> [String]) -> URL? {
        var csvText = columns.joined(separator: ",") + "\n"
        
        for item in data {
            let values = valueExtractor(item)
            let escapedValues = values.map { value in
                // Escape quotes and wrap in quotes if contains comma
                let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
                return escaped.contains(",") ? "\"\(escaped)\"" : escaped
            }
            csvText += escapedValues.joined(separator: ",") + "\n"
        }
        
        let fileName = "export_\(Date().timeIntervalSince1970).csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvText.write(to: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            print("Error writing CSV: \(error)")
            return nil
        }
    }
    
    /// Export businesses to CSV
    static func exportBusinesses(_ businesses: [Business]) -> URL? {
        let columns = ["ID", "Name", "Category", "City", "Country", "Rating", "Reviews", "Owner ID", "Phone", "Status"]
        
        return exportToCSV(data: businesses, columns: columns) { business in
            // Handle claimStatus - it might be an enum or might not have displayName
            let statusText: String
            if let status = business.claimStatus {
                // If claimStatus is an enum with displayName property, use it
                // Otherwise convert to string directly
                statusText = "\(status)"
            } else {
                statusText = "N/A"
            }
            
            return [
                business.id ?? "",
                business.name ?? "",
                business.category ?? "",
                business.city ?? "",
                business.country ?? "",
                String(format: "%.1f", business.rating),
                "\(business.reviewCount)",
                business.ownerId ?? "",
                business.phone ?? "",
                statusText
            ]
        }
    }
    
    /// Export users to CSV
    static func exportUsers(_ users: [UserProfile]) -> URL? {
        let columns = ["UID", "Name", "Email", "Phone", "Role", "Businesses Owned", "Join Date"]
        
        return exportToCSV(data: users, columns: columns) { user in
            let role = user.isAdmin ? "Admin" : (user.isBusinessOwner ? "Business Owner" : "Regular User")
            let businessCount = user.claimedBusinessIds?.count ?? 0
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let joinDate = user.createdAt.map { dateFormatter.string(from: $0) } ?? "N/A"
            
            return [
                user.uid,
                user.name,
                user.email,
                user.phoneNumber ?? "",
                role,
                "\(businessCount)",
                joinDate
            ]
        }
    }
    
    /// Export claims to CSV
    static func exportClaims(_ claims: [BusinessClaim]) -> URL? {
        let columns = ["ID", "Business Name", "Claimant", "Email", "Status", "Submitted Date", "Reviewed By"]
        
        return exportToCSV(data: claims, columns: columns) { claim in
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let submitDate = dateFormatter.string(from: claim.submittedAt)
            
            return [
                claim.id ?? "N/A",
                claim.businessName,
                claim.claimantName,
                claim.claimantEmail,
                claim.status.displayName,
                submitDate,
                claim.reviewerName ?? ""
            ]
        }
    }
    
    /// Export reviews to CSV
    static func exportReviews(_ reviews: [Review]) -> URL? {
        let columns = ["ID", "Business ID", "User", "Rating", "Comment", "Date"]
        
        return exportToCSV(data: reviews, columns: columns) { review in
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let reviewDate = dateFormatter.string(from: review.createdAt)
            
            return [
                review.id ?? "N/A",
                review.businessId,
                review.userName,
                "\(review.rating)",
                review.comment.replacingOccurrences(of: "\n", with: " "),
                reviewDate
            ]
        }
    }
    
    /// Export bookings to CSV
    static func exportBookings(_ bookings: [Booking]) -> URL? {
        let columns = ["ID", "Business", "User", "Date", "Time Slot", "Party Size", "Status"]
        
        return exportToCSV(data: bookings, columns: columns) { booking in
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let bookingDate = dateFormatter.string(from: booking.date)
            
            return [
                booking.id ?? "N/A",
                booking.businessName,
                booking.userName,
                bookingDate,
                booking.timeSlot,
                "\(booking.partySize)",
                booking.status.displayName
            ]
        }
    }
    
    /// Export activity log to CSV
    static func exportActivityLog(_ entries: [ActivityLogEntry]) -> URL? {
        let columns = ["Timestamp", "Admin", "Action", "Target Type", "Target Name", "Details"]
        
        return exportToCSV(data: entries, columns: columns) { entry in
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            let timestamp = dateFormatter.string(from: entry.timestamp)
            
            // Convert action to string - use displayName if available, otherwise convert enum to string
            let actionText = entry.action.rawValue
            
            return [
                timestamp,
                entry.adminName,
                actionText,
                entry.targetType,
                entry.targetName,
                entry.details
            ]
        }
    }
    
    /// Share file using system share sheet
    static func shareFile(url: URL, from viewController: UIViewController? = nil) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // For iPad, set source view
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController?.view
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2,
                                       y: UIScreen.main.bounds.height / 2,
                                       width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        if let vc = viewController {
            vc.present(activityVC, animated: true)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

/// SwiftUI wrapper for export sharing
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

