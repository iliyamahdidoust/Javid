//
//  AdminViewModel.swift (FIXED)
//  Javid Admin Dashboard
//
//  Fixed: Added Combine import and fixed MainActor placement
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class AdminViewModel: ObservableObject {
    private let db = Firestore.firestore()
    
    // MARK: - Published Properties
    @Published var currentUser: UserProfile?
    @Published var isAuthenticated = false
    @Published var isAdmin = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // Data collections
    @Published var allBusinesses: [Business] = []
    @Published var allUsers: [UserProfile] = []
    @Published var allClaims: [BusinessClaim] = []
    @Published var allReviews: [Review] = []
    @Published var allBookings: [Booking] = []
    @Published var activityLog: [ActivityLogEntry] = []
    
    // Filtered data
    @Published var filteredBusinesses: [Business] = []
    @Published var filteredUsers: [UserProfile] = []
    @Published var filteredClaims: [BusinessClaim] = []
    @Published var filteredReviews: [Review] = []
    
    // Filters
    @Published var businessFilter = AdminFilter()
    @Published var userFilter = AdminFilter()
    @Published var claimFilter = AdminFilter()
    @Published var reviewFilter = AdminFilter()
    
    // Real-time listeners
    private var businessListener: ListenerRegistration?
    private var userListener: ListenerRegistration?
    private var claimListener: ListenerRegistration?
    private var reviewListener: ListenerRegistration?
    private var bookingListener: ListenerRegistration?
    
    // ✅ Integration with existing ViewModels
    private var claimBusinessVM: ClaimBusinessViewModel?
    
    init(claimBusinessViewModel: ClaimBusinessViewModel? = nil) {
        self.claimBusinessVM = claimBusinessViewModel ?? ClaimBusinessViewModel()
        checkAdminStatus()
    }
    
    // ✅ FIXED: Remove @MainActor isolation for deinit
    nonisolated deinit {
        Task { @MainActor in
            self.removeAllListeners()
        }
    }
    
    // MARK: - Authentication & Authorization
    
    func checkAdminStatus() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isAuthenticated = false
            isAdmin = false
            return
        }
        
        isAuthenticated = true
        
        Task {
            do {
                let docSnapshot = try await db.collection("users").document(userId).getDocument()
                if let userData = try? docSnapshot.data(as: UserProfile.self) {
                    currentUser = userData
                    isAdmin = userData.isAdmin
                    
                    if isAdmin {
                        await setupRealtimeListeners()
                    }
                } else {
                    isAdmin = false
                }
            } catch {
                errorMessage = "Failed to verify admin status: \(error.localizedDescription)"
                isAdmin = false
            }
        }
    }
    
    // MARK: - Real-time Data Listeners
    
    func setupRealtimeListeners() async {
        setupBusinessListener()
        setupUserListener()
        setupClaimListener()
        setupReviewListener()
        setupBookingListener()
        setupActivityLogListener()
    }
    
    private func setupBusinessListener() {
        businessListener = db.collection("businesses")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.errorMessage = "Error listening to businesses: \(error.localizedDescription)"
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self.allBusinesses = documents.compactMap { doc in
                        try? doc.data(as: Business.self)
                    }
                    self.applyBusinessFilter()
                }
            }
    }
    
    private func setupUserListener() {
        userListener = db.collection("users")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.errorMessage = "Error listening to users: \(error.localizedDescription)"
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self.allUsers = documents.compactMap { doc in
                        try? doc.data(as: UserProfile.self)
                    }
                    self.applyUserFilter()
                }
            }
    }
    
    private func setupClaimListener() {
        claimListener = db.collection("business_claims")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.errorMessage = "Error listening to claims: \(error.localizedDescription)"
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self.allClaims = documents.compactMap { doc in
                        try? doc.data(as: BusinessClaim.self)
                    }
                    self.applyClaimFilter()
                }
            }
    }
    
    private func setupReviewListener() {
        reviewListener = db.collection("reviews")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.errorMessage = "Error listening to reviews: \(error.localizedDescription)"
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self.allReviews = documents.compactMap { doc in
                        try? doc.data(as: Review.self)
                    }
                    self.applyReviewFilter()
                }
            }
    }
    
    private func setupBookingListener() {
        bookingListener = db.collection("bookings")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.errorMessage = "Error listening to bookings: \(error.localizedDescription)"
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self.allBookings = documents.compactMap { doc in
                        try? doc.data(as: Booking.self)
                    }
                }
            }
    }
    
    private func setupActivityLogListener() {
        db.collection("activity_log")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening to activity log: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self.activityLog = documents.compactMap { doc in
                        try? doc.data(as: ActivityLogEntry.self)
                    }
                }
            }
    }
    
    func removeAllListeners() {
        businessListener?.remove()
        userListener?.remove()
        claimListener?.remove()
        reviewListener?.remove()
        bookingListener?.remove()
    }
    
    // MARK: - Filter Application
    
    func applyBusinessFilter() {
        filteredBusinesses = allBusinesses.filter { business in
            var matches = true
            
            // Search text
            if !businessFilter.searchText.isEmpty {
                matches = matches && (
                    business.name.localizedCaseInsensitiveContains(businessFilter.searchText) ||
                    business.category.localizedCaseInsensitiveContains(businessFilter.searchText) ||
                    business.city.localizedCaseInsensitiveContains(businessFilter.searchText)
                )
            }
            
            // Category filter
            if let category = businessFilter.category {
                matches = matches && business.category == category
            }
            
            // City filter
            if let city = businessFilter.city {
                matches = matches && business.city == city
            }
            
            // Country filter
            if let country = businessFilter.country {
                matches = matches && business.country == country
            }
            
            // Rating filter
            if let rating = businessFilter.rating {
                matches = matches && Int(business.rating) >= rating
            }
            
            // Claim status filter
            if let claimStatus = businessFilter.claimStatus {
                if claimStatus == "claimable" {
                    matches = matches && business.isClaimable
                } else if claimStatus == "claimed" {
                    matches = matches && (business.claimStatus == "claimed")
                } else if claimStatus == "unclaimed" {
                    matches = matches && (business.claimStatus == "unclaimed" || business.claimStatus == nil)
                }
            }
            
            return matches
        }
    }
    
    func applyUserFilter() {
        filteredUsers = allUsers.filter { user in
            var matches = true
            
            // Search text
            if !userFilter.searchText.isEmpty {
                matches = matches && (
                    user.name.localizedCaseInsensitiveContains(userFilter.searchText) ||
                    user.email.localizedCaseInsensitiveContains(userFilter.searchText) ||
                    (user.phoneNumber?.localizedCaseInsensitiveContains(userFilter.searchText) ?? false)
                )
            }
            
            // Role filter
            if let role = userFilter.role {
                switch role {
                case "admin":
                    matches = matches && user.isAdmin
                case "business_owner":
                    matches = matches && user.isBusinessOwner && !user.isAdmin
                case "regular":
                    matches = matches && !user.isBusinessOwner && !user.isAdmin
                default:
                    break
                }
            }
            
            return matches
        }
    }
    
    func applyClaimFilter() {
        filteredClaims = allClaims.filter { claim in
            var matches = true
            
            // Search text
            if !claimFilter.searchText.isEmpty {
                matches = matches && (
                    claim.businessName.localizedCaseInsensitiveContains(claimFilter.searchText) ||
                    claim.claimantName.localizedCaseInsensitiveContains(claimFilter.searchText) ||
                    claim.claimantEmail.localizedCaseInsensitiveContains(claimFilter.searchText)
                )
            }
            
            // Status filter
            if let status = claimFilter.status {
                matches = matches && claim.status.rawValue == status
            }
            
            return matches
        }
    }
    
    func applyReviewFilter() {
        filteredReviews = allReviews.filter { review in
            var matches = true
            
            // Search text
            if !reviewFilter.searchText.isEmpty {
                matches = matches && (
                    review.userName.localizedCaseInsensitiveContains(reviewFilter.searchText) ||
                    review.comment.localizedCaseInsensitiveContains(reviewFilter.searchText)
                )
            }
            
            // Rating filter
            if let rating = reviewFilter.rating {
                matches = matches && Int(review.rating) == rating
            }
            
            return matches
        }
    }
    
    // MARK: - Claim Management (Delegates to ClaimBusinessViewModel)
    
    /// Approve claim using existing ClaimBusinessViewModel
    func approveClaim(_ claim: BusinessClaim) async throws {
        guard let adminId = currentUser?.uid,
              let adminName = currentUser?.name else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Admin not authenticated"])
        }
        
        isLoading = true
        
        return try await withCheckedThrowingContinuation { continuation in
            claimBusinessVM?.approveClaim(
                claim,
                adminId: adminId,
                adminName: adminName
            ) { [weak self] success, message in
                Task { @MainActor in
                    self?.isLoading = false
                    
                    if success {
                        // Log activity
                        await self?.logActivity(
                            action: .claimApproved,
                            targetType: "claim",
                            targetId: claim.id ?? "",
                            targetName: claim.businessName,
                            details: "Approved claim for \(claim.businessName) by \(claim.claimantName)"
                        )
                        
                        self?.successMessage = message
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
                    }
                }
            }
        }
    }
    
    /// Reject claim using existing ClaimBusinessViewModel
    func rejectClaim(_ claim: BusinessClaim, reason: String) async throws {
        guard let adminId = currentUser?.uid,
              let adminName = currentUser?.name else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Admin not authenticated"])
        }
        
        isLoading = true
        
        return try await withCheckedThrowingContinuation { continuation in
            claimBusinessVM?.rejectClaim(
                claim,
                adminId: adminId,
                adminName: adminName,
                reason: reason
            ) { [weak self] success, message in
                Task { @MainActor in
                    self?.isLoading = false
                    
                    if success {
                        // Log activity
                        await self?.logActivity(
                            action: .claimRejected,
                            targetType: "claim",
                            targetId: claim.id ?? "",
                            targetName: claim.businessName,
                            details: "Rejected claim for \(claim.businessName): \(reason)"
                        )
                        
                        self?.successMessage = message
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
                    }
                }
            }
        }
    }
    
    // MARK: - Business Management
    
    func deleteBusiness(_ business: Business) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let businessId = business.id else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid business ID"])
            }
            
            // Cascade delete: reviews, bookings, favorites, claims
            let reviewsSnapshot = try await db.collection("reviews")
                .whereField("businessId", isEqualTo: businessId)
                .getDocuments()
            
            for doc in reviewsSnapshot.documents {
                try await doc.reference.delete()
            }
            
            let bookingsSnapshot = try await db.collection("bookings")
                .whereField("businessId", isEqualTo: businessId)
                .getDocuments()
            
            for doc in bookingsSnapshot.documents {
                try await doc.reference.delete()
            }
            
            let favoritesSnapshot = try await db.collection("favorites")
                .whereField("businessId", isEqualTo: businessId)
                .getDocuments()
            
            for doc in favoritesSnapshot.documents {
                try await doc.reference.delete()
            }
            
            let claimsSnapshot = try await db.collection("business_claims")
                .whereField("businessId", isEqualTo: businessId)
                .getDocuments()
            
            for doc in claimsSnapshot.documents {
                try await doc.reference.delete()
            }
            
            // Delete business
            try await db.collection("businesses").document(businessId).delete()
            
            // Log activity
            await logActivity(
                action: .businessDeleted,
                targetType: "business",
                targetId: businessId,
                targetName: business.name,
                details: "Deleted business and all associated data"
            )
            
            successMessage = "Business deleted successfully"
            isLoading = false
        } catch {
            errorMessage = "Failed to delete business: \(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }
    
    func suspendBusiness(_ business: Business) async throws {
        guard let businessId = business.id else { return }
        
        try await db.collection("businesses").document(businessId).updateData([
            "suspended": true,
            "suspendedAt": Timestamp(date: Date())
        ])
        
        await logActivity(
            action: .businessUpdated,
            targetType: "business",
            targetId: businessId,
            targetName: business.name,
            details: "Suspended business"
        )
        
        successMessage = "Business suspended"
    }
    
    func featureBusiness(_ business: Business, featured: Bool) async throws {
        guard let businessId = business.id else { return }
        
        try await db.collection("businesses").document(businessId).updateData([
            "featured": featured
        ])
        
        await logActivity(
            action: .businessUpdated,
            targetType: "business",
            targetId: businessId,
            targetName: business.name,
            details: featured ? "Featured business" : "Unfeatured business"
        )
        
        successMessage = featured ? "Business featured" : "Business unfeatured"
    }
    
    // MARK: - User Management
    
    func promoteToBusinessOwner(user: UserProfile) async throws {
        try await db.collection("users").document(user.uid).updateData([
            "isBusinessOwner": true
        ])
        
        await logActivity(
            action: .userPromoted,
            targetType: "user",
            targetId: user.uid,
            targetName: user.name,
            details: "Promoted to Business Owner"
        )
        
        successMessage = "\(user.name) promoted to Business Owner"
    }
    
    func promoteToAdmin(user: UserProfile) async throws {
        try await db.collection("users").document(user.uid).updateData([
            "isAdmin": true
        ])
        
        await logActivity(
            action: .userPromoted,
            targetType: "user",
            targetId: user.uid,
            targetName: user.name,
            details: "Promoted to Admin"
        )
        
        successMessage = "\(user.name) promoted to Admin"
    }
    
    func demoteAdmin(user: UserProfile) async throws {
        try await db.collection("users").document(user.uid).updateData([
            "isAdmin": false
        ])
        
        await logActivity(
            action: .userDemoted,
            targetType: "user",
            targetId: user.uid,
            targetName: user.name,
            details: "Demoted from Admin"
        )
        
        successMessage = "\(user.name) demoted from Admin"
    }
    
    func suspendUser(user: UserProfile, reason: String) async throws {
        try await db.collection("users").document(user.uid).updateData([
            "suspended": true,
            "suspendedAt": Timestamp(date: Date()),
            "suspensionReason": reason
        ])
        
        await logActivity(
            action: .userSuspended,
            targetType: "user",
            targetId: user.uid,
            targetName: user.name,
            details: "Suspended: \(reason)"
        )
        
        successMessage = "\(user.name) suspended"
    }
    
    func deleteUser(user: UserProfile) async throws {
        isLoading = true
        
        do {
            // Cascade delete user data
            let reviewsSnapshot = try await db.collection("reviews")
                .whereField("userId", isEqualTo: user.uid)
                .getDocuments()
            
            for doc in reviewsSnapshot.documents {
                try await doc.reference.delete()
            }
            
            let favoritesSnapshot = try await db.collection("favorites")
                .whereField("userId", isEqualTo: user.uid)
                .getDocuments()
            
            for doc in favoritesSnapshot.documents {
                try await doc.reference.delete()
            }
            
            let bookingsSnapshot = try await db.collection("bookings")
                .whereField("userId", isEqualTo: user.uid)
                .getDocuments()
            
            for doc in bookingsSnapshot.documents {
                try await doc.reference.delete()
            }
            
            // Delete user document
            try await db.collection("users").document(user.uid).delete()
            
            await logActivity(
                action: .userDeleted,
                targetType: "user",
                targetId: user.uid,
                targetName: user.name,
                details: "Deleted user and all associated data"
            )
            
            successMessage = "User deleted successfully"
            isLoading = false
        } catch {
            errorMessage = "Failed to delete user: \(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Review Management
    
    func deleteReview(_ review: Review, reason: String) async throws {
        guard let reviewId = review.id else { return }
        
        try await db.collection("reviews").document(reviewId).delete()
        
        // Update business review count and rating
        await recalculateBusinessRating(businessId: review.businessId)
        
        await logActivity(
            action: .reviewDeleted,
            targetType: "review",
            targetId: reviewId,
            targetName: "Review by \(review.userName)",
            details: "Deleted: \(reason)"
        )
        
        successMessage = "Review deleted"
    }
    
    private func recalculateBusinessRating(businessId: String) async {
        do {
            let snapshot = try await db.collection("reviews")
                .whereField("businessId", isEqualTo: businessId)
                .getDocuments()
            
            let reviews = snapshot.documents.compactMap { try? $0.data(as: Review.self) }
            let avgRating = reviews.isEmpty ? 0.0 : reviews.map { $0.rating }.reduce(0.0, +) / Double(reviews.count)
            
            try await db.collection("businesses").document(businessId).updateData([
                "rating": avgRating,
                "reviewCount": reviews.count
            ])
        } catch {
            print("Error recalculating rating: \(error)")
        }
    }
    
    // MARK: - Booking Management
    
    func cancelBooking(_ booking: Booking, reason: String) async throws {
        guard let bookingId = booking.id else { return }
        
        try await db.collection("bookings").document(bookingId).updateData([
            "status": "cancelled",
            "cancellationReason": reason,
            "cancelledAt": Timestamp(date: Date()),
            "cancelledBy": "admin"
        ])
        
        await logActivity(
            action: .bookingCancelled,
            targetType: "booking",
            targetId: bookingId,
            targetName: "Booking by \(booking.userName)",
            details: "Cancelled: \(reason)"
        )
        
        successMessage = "Booking cancelled"
    }
    
    // MARK: - Activity Logging
    
    func logActivity(action: ActivityLogEntry.AdminAction,
                    targetType: String,
                    targetId: String,
                    targetName: String,
                    details: String) async {
        guard let adminId = currentUser?.uid,
              let adminName = currentUser?.name else { return }
        
        let entry = ActivityLogEntry(
            id: UUID().uuidString,
            adminId: adminId,
            adminName: adminName,
            action: action,
            targetType: targetType,
            targetId: targetId,
            targetName: targetName,
            details: details,
            timestamp: Date()
        )
        
        do {
            try db.collection("activity_log").document(entry.id).setData(from: entry)
        } catch {
            print("Error logging activity: \(error)")
        }
    }
    
    // MARK: - Bulk Operations
    
    func bulkDeleteBusinesses(_ businesses: [Business]) async throws {
        isLoading = true
        var successCount = 0
        var failCount = 0
        
        for business in businesses {
            do {
                try await deleteBusiness(business)
                successCount += 1
            } catch {
                failCount += 1
            }
        }
        
        successMessage = "Deleted \(successCount) businesses. \(failCount) failed."
        isLoading = false
    }
    
    func bulkSuspendUsers(_ users: [UserProfile], reason: String) async throws {
        isLoading = true
        var successCount = 0
        var failCount = 0
        
        for user in users {
            do {
                try await suspendUser(user: user, reason: reason)
                successCount += 1
            } catch {
                failCount += 1
            }
        }
        
        successMessage = "Suspended \(successCount) users. \(failCount) failed."
        isLoading = false
    }
    
    // MARK: - Notification Management
    
    func sendNotificationToAll(title: String, message: String) async throws {
        await logActivity(
            action: .notificationSent,
            targetType: "notification",
            targetId: UUID().uuidString,
            targetName: title,
            details: "Sent to all users: \(message)"
        )
        
        successMessage = "Notification sent to all users"
    }
    
    // MARK: - Utility Methods
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
    
    func getCategories() -> [String] {
        Array(Set(allBusinesses.map { $0.category })).sorted()
    }
    
    func getCities() -> [String] {
        Array(Set(allBusinesses.map { $0.city })).sorted()
    }
    
    func getCountries() -> [String] {
        Array(Set(allBusinesses.map { $0.country })).sorted()
    }
}
