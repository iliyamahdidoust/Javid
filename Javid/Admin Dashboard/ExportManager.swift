//
//  ExportManager.swift
//  Javid Admin Panel
//
//  Export data to various formats (CSV, JSON)
//

import Foundation
import SwiftUI

class ExportManager {
    
    // MARK: - CSV Export
    
    static func exportToCSV<T>(
        data: [T],
        columns: [String],
        valueExtractor: (T) -> [String]
    ) -> URL? {
        var csvText = columns.joined(separator: ",") + "\n"
        
        for item in data {
            let values = valueExtractor(item)
            let escapedValues = values.map { value in
                let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
                return escaped.contains(",") || escaped.contains("\n") ? "\"\(escaped)\"" : escaped
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
    
    // MARK: - Business Export
    
    static func exportBusinesses(_ businesses: [Business]) -> URL? {
        let columns = [
            "ID", "Name", "Category", "City", "Country",
            "Rating", "Reviews", "Owner ID", "Phone",
            "Claimable", "Claim Status", "Featured", "Suspended"
        ]
        
        return exportToCSV(data: businesses, columns: columns) { business in
            [
                business.id ?? "",
                business.name,
                business.category,
                business.city,
                business.country,
                String(format: "%.1f", business.rating),
                "\(business.reviewCount)",
                business.ownerId,
                business.phone,
                business.isClaimable ? "Yes" : "No",
                business.claimStatus ?? "N/A",
                business.featured ? "Yes" : "No",
                business.suspended ? "Yes" : "No"
            ]
        }
    }
    
    // MARK: - User Export
    
    static func exportUsers(_ users: [UserProfile]) -> URL? {
        let columns = [
            "UID", "Name", "Email", "Phone", "Is Admin",
            "Is Business Owner", "Claimed Businesses", "Join Date"
        ]
        
        return exportToCSV(data: users, columns: columns) { user in
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let joinDate = user.createdAt.map { dateFormatter.string(from: $0) } ?? "N/A"
            
            return [
                user.uid,
                user.name,
                user.email,
                user.phoneNumber ?? "",
                user.isAdmin ? "Yes" : "No",
                user.isBusinessOwner ? "Yes" : "No",
                "\(user.claimedBusinessIds?.count ?? 0)",
                joinDate
            ]
        }
    }
    
    // MARK: - Claim Export
    
    static func exportClaims(_ claims: [BusinessClaim]) -> URL? {
        let columns = [
            "ID", "Business Name", "Claimant Name", "Claimant Email",
            "Status", "Email Verified", "Documents", "Submitted Date", "Reviewed By"
        ]
        
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
                claim.emailVerified ? "Yes" : "No",
                "\(claim.verificationDocuments.count)",
                submitDate,
                claim.reviewerName ?? "Not reviewed"
            ]
        }
    }
    
    // MARK: - Review Export
    
    static func exportReviews(_ reviews: [Review]) -> URL? {
        let columns = [
            "ID", "Business ID", "User Name", "User Email",
            "Rating", "Comment", "Date", "Has Owner Response"
        ]
        
        return exportToCSV(data: reviews, columns: columns) { review in
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let reviewDate = dateFormatter.string(from: review.createdAt)
            
            return [
                review.id ?? "N/A",
                review.businessId,
                review.userName,
                review.userEmail,
                "\(review.rating)",
                review.comment.replacingOccurrences(of: "\n", with: " "),
                reviewDate,
                review.ownerResponse != nil ? "Yes" : "No"
            ]
        }
    }
    
    // MARK: - Booking Export
    
    static func exportBookings(_ bookings: [Booking]) -> URL? {
        let columns = [
            "ID", "Business Name", "User Name", "User Email", "User Phone",
            "Date", "Time Slot", "Party Size", "Status", "Special Requests"
        ]
        
        return exportToCSV(data: bookings, columns: columns) { booking in
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let bookingDate = dateFormatter.string(from: booking.date)
            
            return [
                booking.id ?? "N/A",
                booking.businessName,
                booking.userName,
                booking.userEmail,
                booking.userPhone,
                bookingDate,
                booking.timeSlot,
                "\(booking.partySize)",
                booking.status.displayName,
                booking.specialRequests ?? ""
            ]
        }
    }
    
    // MARK: - Activity Log Export
    
    static func exportActivityLog(_ entries: [ActivityLogEntry]) -> URL? {
        let columns = [
            "Timestamp", "Admin Name", "Action", "Target Type",
            "Target Name", "Details"
        ]
        
        return exportToCSV(data: entries, columns: columns) { entry in
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            let timestamp = dateFormatter.string(from: entry.timestamp)
            
            return [
                timestamp,
                entry.adminName,
                entry.action.rawValue,
                entry.targetType,
                entry.targetName,
                entry.details
            ]
        }
    }
    
    // MARK: - JSON Export
    
    static func exportToJSON<T: Encodable>(_ data: [T], filename: String) -> URL? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let jsonData = try encoder.encode(data)
            let fileName = "\(filename)_\(Date().timeIntervalSince1970).json"
            let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try jsonData.write(to: path)
            return path
        } catch {
            print("Error creating JSON: \(error)")
            return nil
        }
    }
}


extension BusinessClaimStatus {
    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .approved:
            return "Approved"
        case .rejected:
            return "Rejected"
        case .underReview:
            return "Under Review"
        @unknown default:
            return String(describing: self)
        }
    }
}
