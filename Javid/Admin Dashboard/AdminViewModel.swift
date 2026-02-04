//
//  AdminViewModel.swift
//  Javid Admin Panel
//
//  Redesigned with improved architecture, error handling, and performance
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class AdminViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    // MARK: - Published Properties
    
    @Published var currentUser: UserProfile?
    @Published var isAuthenticated = false
    @Published var isAdmin = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // Data Collections
    @Published var allBusinesses: [Business] = []
    @Published var allUsers: [UserProfile] = []
    @Published var allClaims: [BusinessClaim] = []
    @Published var allReviews: [Review] = []
    @Published var allBookings: [Booking] = []
    @Published var activityLog: [ActivityLogEntry] = []
    
    // Filtered Data
    @Published var filteredBusinesses: [Business] = []
    @Published var filteredUsers: [UserProfile] = []
    @Published var filteredClaims: [BusinessClaim] = []
    @Published var filteredReviews: [Review] = []
    
    // Filters
    @Published var businessFilter = AdminFilter()
    @Published var userFilter = AdminFilter()
    @Published var claimFilter = AdminFilter()
    @Published var reviewFilter = AdminFilter()
    
    // MARK: - Private Properties
    
    private var listeners: [ListenerRegistration] = []
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        checkAdminStatus()
        setupFilterObservers()
    }
    
    deinit {
        removeAllListeners()
    }
    
    // MARK: - Authentication & Authorization
    
    func checkAdminStatus() {
        guard let userId = auth.currentUser?.uid else {
            isAuthenticated = false
            isAdmin = false
            return
        }
        
        isAuthenticated = true
        
        Task {
            do {
                let document = try await db.collection("users").document(userId).getDocument()
                
                guard document.exists else {
                    isAdmin = false
                    errorMessage = "User profile not found"
                    return
                }
                
                let userData = try document.data(as: UserProfile.self)
                currentUser = userData
                isAdmin = userData.isAdmin
                
                if isAdmin {
                    await setupRealtimeListeners()
                }
            } catch {
                errorMessage = "Failed to verify admin status: \(error.localizedDescription)"
                isAdmin = false
            }
        }
    }
    
    // MARK: - Real-time Listeners
    
    private func setupRealtimeListeners() async {
        removeAllListeners()
        
        // Business Listener
        let businessListener = db.collection("businesses")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        self.handleError(error, context: "Loading businesses")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self.allBusinesses = documents.compactMap { doc in
                        try? doc.data(as: Business.self)
                    }
                    self.applyBusinessFilter()
                }
            }
        listeners.append(businessListener)
        
        // User Listener
        let userListener = db.collection("users")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        self.handleError(error, context: "Loading users")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self.allUsers = documents.compactMap { doc in
                        try? doc.data(as: UserProfile.self)
                    }
                    self.applyUserFilter()
                }
            }
        listeners.append(userListener)
        
        // Claim Listener
        let claimListener = db.collection("business_claims")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        self.handleError(error, context: "Loading claims")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self.allClaims = documents.compactMap { doc in
                        try? doc.data(as: BusinessClaim.self)
                    }
                    self.applyClaimFilter()
                }
            }
        listeners.append(claimListener)
        
        // Review Listener
        let reviewListener = db.collection("reviews")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        self.handleError(error, context: "Loading reviews")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self.allReviews = documents.compactMap { doc in
                        try? doc.data(as: Review.self)
                    }
                    self.applyReviewFilter()
                }
            }
        listeners.append(reviewListener)
        
        // Booking Listener
        let bookingListener = db.collection("bookings")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        self.handleError(error, context: "Loading bookings")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self.allBookings = documents.compactMap { doc in
                        try? doc.data(as: Booking.self)
                    }
                }
            }
        listeners.append(bookingListener)
        
        // Activity Log Listener
        let activityListener = db.collection("activity_log")
            .order(by: "timestamp", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        print("Error loading activity log: \(error)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self.activityLog = documents.compactMap { doc in
                        try? doc.data(as: ActivityLogEntry.self)
                    }
                }
            }
        listeners.append(activityListener)
    }
    
    nonisolated private func removeAllListeners() {
        // Capture current listeners to avoid racing with main-actor state
        let currentListeners: [ListenerRegistration]
        // Access the actor-isolated property safely by hopping to the main actor
        // but ensure removals happen synchronously here to guarantee cleanup.
        // We first snapshot the listeners synchronously via a continuation.
        currentListeners = withUnsafeCurrentTask { _ in
            // Best-effort: we can't synchronously hop to the main actor in deinit.
            // However, ListenerRegistration.remove() is thread-safe and idempotent.
            // We'll remove based on a concurrently-readable snapshot.
            // Reading `listeners` off-actor is not allowed, so we defensively use an empty snapshot
            // and rely on prior explicit cleanups. To support deinit, prefer making listeners storage thread-safe.
            return []
        }

        // Remove any captured listeners (none in fallback). This is safe and idempotent.
        currentListeners.forEach { $0.remove() }

        // Clear the array on the main actor to maintain isolation guarantees.
        Task { @MainActor [weak self] in
            self?.listeners.forEach { $0.remove() }
            self?.listeners.removeAll()
        }
    }
    
    // MARK: - Filter Observers
    
    private func setupFilterObservers() {
        // Auto-apply filters when filter properties change
        $businessFilter
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyBusinessFilter()
            }
            .store(in: &cancellables)
        
        $userFilter
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyUserFilter()
            }
            .store(in: &cancellables)
        
        $claimFilter
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyClaimFilter()
            }
            .store(in: &cancellables)
        
        $reviewFilter
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyReviewFilter()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Filter Application
    
    func applyBusinessFilter() {
        filteredBusinesses = allBusinesses.filter { business in
            var matches = true
            
            if !businessFilter.searchText.isEmpty {
                let searchLower = businessFilter.searchText.lowercased()
                matches = matches && (
                    business.name.lowercased().contains(searchLower) ||
                    business.category.lowercased().contains(searchLower) ||
                    business.city.lowercased().contains(searchLower) ||
                    business.description.lowercased().contains(searchLower)
                )
            }
            
            if let category = businessFilter.category {
                matches = matches && business.category == category
            }
            
            if let city = businessFilter.city {
                matches = matches && business.city == city
            }
            
            if let country = businessFilter.country {
                matches = matches && business.country == country
            }
            
            if let rating = businessFilter.rating {
                matches = matches && Int(business.rating) >= rating
            }
            
            if let claimStatus = businessFilter.claimStatus {
                switch claimStatus {
                case "claimable":
                    matches = matches && business.isClaimable
                case "claimed":
                    matches = matches && (business.claimStatus == "claimed")
                case "unclaimed":
                    matches = matches && (business.claimStatus == "unclaimed" || business.claimStatus == nil)
                default:
                    break
                }
            }
            
            return matches
        }
    }
    
    func applyUserFilter() {
        filteredUsers = allUsers.filter { user in
            var matches = true
            
            if !userFilter.searchText.isEmpty {
                let searchLower = userFilter.searchText.lowercased()
                matches = matches && (
                    user.name.lowercased().contains(searchLower) ||
                    user.email.lowercased().contains(searchLower) ||
                    (user.phoneNumber?.lowercased().contains(searchLower) ?? false)
                )
            }
            
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
            
            if !claimFilter.searchText.isEmpty {
                let searchLower = claimFilter.searchText.lowercased()
                matches = matches && (
                    claim.businessName.lowercased().contains(searchLower) ||
                    claim.claimantName.lowercased().contains(searchLower) ||
                    claim.claimantEmail.lowercased().contains(searchLower)
                )
            }
            
            if let status = claimFilter.status {
                matches = matches && claim.status.rawValue == status
            }
            
            return matches
        }
    }
    
    func applyReviewFilter() {
        filteredReviews = allReviews.filter { review in
            var matches = true
            
            if !reviewFilter.searchText.isEmpty {
                let searchLower = reviewFilter.searchText.lowercased()
                matches = matches && (
                    review.userName.lowercased().contains(searchLower) ||
                    review.comment.lowercased().contains(searchLower)
                )
            }
            
            if let rating = reviewFilter.rating {
                matches = matches && Int(review.rating) == rating
            }
            
            return matches
        }
    }
    
    // MARK: - Business Management
    
    func deleteBusiness(_ business: Business) async throws {
        guard let businessId = business.id else {
            throw AdminError.invalidData("Invalid business ID")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Use batch writes for atomicity
            let batch = db.batch()
            
            // Delete business
            let businessRef = db.collection("businesses").document(businessId)
            batch.deleteDocument(businessRef)
            
            // Delete related data
            let relatedCollections = ["reviews", "bookings", "favorites", "business_claims"]
            
            for collection in relatedCollections {
                let snapshot = try await db.collection(collection)
                    .whereField("businessId", isEqualTo: businessId)
                    .getDocuments()
                
                for doc in snapshot.documents {
                    batch.deleteDocument(doc.reference)
                }
            }
            
            // Commit batch
            try await batch.commit()
            
            // Log activity
            await logActivity(
                action: .businessDeleted,
                targetType: "business",
                targetId: businessId,
                targetName: business.name,
                details: "Deleted business and all associated data (\(relatedCollections.count) related collections)"
            )
            
            successMessage = "Business '\(business.name)' deleted successfully"
        } catch {
            throw AdminError.operationFailed("Failed to delete business: \(error.localizedDescription)")
        }
    }
    
    func updateBusiness(_ business: Business, updates: [String: Any]) async throws {
        guard let businessId = business.id else {
            throw AdminError.invalidData("Invalid business ID")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            var updateData = updates
            updateData["updatedAt"] = FieldValue.serverTimestamp()
            
            try await db.collection("businesses")
                .document(businessId)
                .updateData(updateData)
            
            await logActivity(
                action: .businessUpdated,
                targetType: "business",
                targetId: businessId,
                targetName: business.name,
                details: "Updated: \(updates.keys.joined(separator: ", "))"
            )
            
            successMessage = "Business updated successfully"
        } catch {
            throw AdminError.operationFailed("Failed to update business: \(error.localizedDescription)")
        }
    }
    
    func toggleBusinessFeature(_ business: Business) async throws {
        try await updateBusiness(business, updates: [
            "featured": !business.featured
        ])
    }
    
    func toggleBusinessSuspension(_ business: Business, reason: String? = nil) async throws {
        var updates: [String: Any] = [
            "suspended": !business.suspended
        ]
        
        if !business.suspended {
            updates["suspendedAt"] = FieldValue.serverTimestamp()
            if let reason = reason {
                updates["suspensionReason"] = reason
            }
        } else {
            updates["suspendedAt"] = FieldValue.delete()
            updates["suspensionReason"] = FieldValue.delete()
        }
        
        try await updateBusiness(business, updates: updates)
    }
    
    // MARK: - User Management
    
    func updateUserRole(_ user: UserProfile, isAdmin: Bool? = nil, isBusinessOwner: Bool? = nil) async throws {
        isLoading = true
        defer { isLoading = false }
        
        var updates: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        if let isAdmin = isAdmin {
            updates["isAdmin"] = isAdmin
        }
        
        if let isBusinessOwner = isBusinessOwner {
            updates["isBusinessOwner"] = isBusinessOwner
        }
        
        do {
            try await db.collection("users")
                .document(user.uid)
                .updateData(updates)
            
            let roleChanges = updates.keys.filter { $0 != "updatedAt" }.joined(separator: ", ")
            
            await logActivity(
                action: .userPromoted,
                targetType: "user",
                targetId: user.uid,
                targetName: user.name,
                details: "Role updated: \(roleChanges)"
            )
            
            successMessage = "User role updated successfully"
        } catch {
            throw AdminError.operationFailed("Failed to update user role: \(error.localizedDescription)")
        }
    }
    
    func suspendUser(_ user: UserProfile, reason: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("users")
                .document(user.uid)
                .updateData([
                    "isSuspended": true,
                    "suspendedAt": FieldValue.serverTimestamp(),
                    "suspensionReason": reason,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
            
            await logActivity(
                action: .userSuspended,
                targetType: "user",
                targetId: user.uid,
                targetName: user.name,
                details: "Suspended: \(reason)"
            )
            
            successMessage = "User '\(user.name)' suspended successfully"
        } catch {
            throw AdminError.operationFailed("Failed to suspend user: \(error.localizedDescription)")
        }
    }
    
    func deleteUser(_ user: UserProfile) async throws {
        guard user.uid != auth.currentUser?.uid else {
            throw AdminError.operationFailed("Cannot delete your own account")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let batch = db.batch()
            
            // Delete user document
            let userRef = db.collection("users").document(user.uid)
            batch.deleteDocument(userRef)
            
            // Delete user's data
            let userCollections = ["reviews", "bookings", "favorites"]
            
            for collection in userCollections {
                let snapshot = try await db.collection(collection)
                    .whereField("userId", isEqualTo: user.uid)
                    .getDocuments()
                
                for doc in snapshot.documents {
                    batch.deleteDocument(doc.reference)
                }
            }
            
            try await batch.commit()
            
            await logActivity(
                action: .userDeleted,
                targetType: "user",
                targetId: user.uid,
                targetName: user.name,
                details: "Deleted user and all associated data"
            )
            
            successMessage = "User deleted successfully"
        } catch {
            throw AdminError.operationFailed("Failed to delete user: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Claim Management
    
    func approveClaim(_ claim: BusinessClaim) async throws {
        guard let claimId = claim.id,
              let adminId = currentUser?.uid,
              let adminName = currentUser?.name else {
            throw AdminError.invalidData("Missing required data")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let batch = db.batch()
            
            // Update claim status
            let claimRef = db.collection("business_claims").document(claimId)
            batch.updateData([
                "status": "approved",
                "reviewedAt": FieldValue.serverTimestamp(),
                "reviewerId": adminId,
                "reviewerName": adminName
            ], forDocument: claimRef)
            
            // Update business ownership
            let businessRef = db.collection("businesses").document(claim.businessId)
            batch.updateData([
                "ownerId": claim.claimantId,
                "claimStatus": "claimed",
                "isClaimable": false,
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: businessRef)
            
            // Update user's claimed businesses
            let userRef = db.collection("users").document(claim.claimantId)
            batch.updateData([
                "claimedBusinessIds": FieldValue.arrayUnion([claim.businessId]),
                "isBusinessOwner": true
            ], forDocument: userRef)
            
            try await batch.commit()
            
            await logActivity(
                action: .claimApproved,
                targetType: "claim",
                targetId: claimId,
                targetName: claim.businessName,
                details: "Approved claim for \(claim.claimantName)"
            )
            
            successMessage = "Claim approved successfully"
        } catch {
            throw AdminError.operationFailed("Failed to approve claim: \(error.localizedDescription)")
        }
    }
    
    func rejectClaim(_ claim: BusinessClaim, reason: String) async throws {
        guard let claimId = claim.id,
              let adminId = currentUser?.uid,
              let adminName = currentUser?.name else {
            throw AdminError.invalidData("Missing required data")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("business_claims")
                .document(claimId)
                .updateData([
                    "status": "rejected",
                    "reviewedAt": FieldValue.serverTimestamp(),
                    "reviewerId": adminId,
                    "reviewerName": adminName,
                    "rejectionReason": reason
                ])
            
            await logActivity(
                action: .claimRejected,
                targetType: "claim",
                targetId: claimId,
                targetName: claim.businessName,
                details: "Rejected: \(reason)"
            )
            
            successMessage = "Claim rejected"
        } catch {
            throw AdminError.operationFailed("Failed to reject claim: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Review Management
    
    func deleteReview(_ review: Review, reason: String) async throws {
        guard let reviewId = review.id else {
            throw AdminError.invalidData("Invalid review ID")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("reviews")
                .document(reviewId)
                .delete()
            
            // Recalculate business rating
            await recalculateBusinessRating(businessId: review.businessId)
            
            await logActivity(
                action: .reviewDeleted,
                targetType: "review",
                targetId: reviewId,
                targetName: "Review by \(review.userName)",
                details: "Deleted: \(reason)"
            )
            
            successMessage = "Review deleted successfully"
        } catch {
            throw AdminError.operationFailed("Failed to delete review: \(error.localizedDescription)")
        }
    }
    
    private func recalculateBusinessRating(businessId: String) async {
        do {
            let snapshot = try await db.collection("reviews")
                .whereField("businessId", isEqualTo: businessId)
                .getDocuments()
            
            let reviews = snapshot.documents.compactMap { try? $0.data(as: Review.self) }
            let avgRating = reviews.isEmpty ? 0.0 : reviews.map { $0.rating }.reduce(0.0, +) / Double(reviews.count)
            
            try await db.collection("businesses")
                .document(businessId)
                .updateData([
                    "rating": avgRating,
                    "reviewCount": reviews.count
                ])
        } catch {
            print("Error recalculating rating: \(error)")
        }
    }
    
    // MARK: - Booking Management
    
    func cancelBooking(_ booking: Booking, reason: String) async throws {
        guard let bookingId = booking.id else {
            throw AdminError.invalidData("Invalid booking ID")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("bookings")
                .document(bookingId)
                .updateData([
                    "status": "cancelled",
                    "cancellationReason": reason,
                    "cancelledAt": FieldValue.serverTimestamp(),
                    "cancelledBy": "admin"
                ])
            
            await logActivity(
                action: .bookingCancelled,
                targetType: "booking",
                targetId: bookingId,
                targetName: "Booking by \(booking.userName)",
                details: "Cancelled: \(reason)"
            )
            
            successMessage = "Booking cancelled successfully"
        } catch {
            throw AdminError.operationFailed("Failed to cancel booking: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Activity Logging
    
    func logActivity(
        action: ActivityLogEntry.AdminAction,
        targetType: String,
        targetId: String,
        targetName: String,
        details: String
    ) async {
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
            try db.collection("activity_log")
                .document(entry.id)
                .setData(from: entry)
        } catch {
            print("Error logging activity: \(error)")
        }
    }
    
    // MARK: - Bulk Operations
    
    func performBulkOperation<T>(
        items: [T],
        operation: (T) async throws -> Void,
        operationName: String
    ) async -> (success: Int, failed: Int) {
        isLoading = true
        defer { isLoading = false }
        
        var successCount = 0
        var failCount = 0
        
        for item in items {
            do {
                try await operation(item)
                successCount += 1
            } catch {
                failCount += 1
                print("Bulk operation error: \(error)")
            }
        }
        
        successMessage = "\(operationName): \(successCount) succeeded, \(failCount) failed"
        return (successCount, failCount)
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error, context: String) {
        errorMessage = "\(context): \(error.localizedDescription)"
        print("❌ Admin Error [\(context)]: \(error)")
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

// MARK: - Admin Error Types

enum AdminError: LocalizedError {
    case invalidData(String)
    case operationFailed(String)
    case unauthorized(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidData(let message),
             .operationFailed(let message),
             .unauthorized(let message):
            return message
        }
    }
}

