import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI
import Combine

class ClaimBusinessViewModel: ObservableObject {
    @Published var claims: [BusinessClaim] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var successMessage = ""
    
    // Current claim being processed
    @Published var currentClaim: BusinessClaim?
    
    // Document upload progress
    @Published var uploadProgress: Double = 0
    @Published var isUploadingDocument = false
    
    private let db = Firestore.firestore()
    private var claimListener: ListenerRegistration?
    
    deinit {
        claimListener?.remove()
    }
    
    // MARK: - Fetch User's Claims
    
    /// Get all claims submitted by current user
    func fetchUserClaims() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not logged in"
            return
        }
        
        isLoading = true
        
        claimListener = db.collection("business_claims")
            .whereField("claimantId", isEqualTo: userId)
            .order(by: "submittedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Failed to load claims: \(error.localizedDescription)"
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.claims = []
                    return
                }
                
                self.claims = documents.compactMap { doc in
                    try? doc.data(as: BusinessClaim.self)
                }
                
                print("✅ Loaded \(self.claims.count) claims for user")
            }
    }
    
    // MARK: - Check Existing Claim
    
    /// Check if user already has a claim for this business
    func checkExistingClaim(for businessId: String, completion: @escaping (BusinessClaim?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        
        db.collection("business_claims")
            .whereField("businessId", isEqualTo: businessId)
            .whereField("claimantId", isEqualTo: userId)
            .whereField("status", in: [
                ClaimStatus.pending.rawValue,
                ClaimStatus.underReview.rawValue
            ])
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error checking existing claim: \(error)")
                    completion(nil)
                    return
                }
                
                if let claim = snapshot?.documents.first,
                   let businessClaim = try? claim.data(as: BusinessClaim.self) {
                    completion(businessClaim)
                } else {
                    completion(nil)
                }
            }
    }
    
    // MARK: - Submit Claim
    
    /// Submit a new business claim
    func submitClaim(
        business: Business,
        userProfile: UserProfile,
        documents: [ClaimVerificationDocument],
        additionalNotes: String?,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false, "You must be logged in to claim a business")
            return
        }
        
        // Validation
        guard business.isClaimable else {
            completion(false, "This business is not available for claiming")
            return
        }
        
        guard business.ownerId != userId else {
            completion(false, "You already own this business")
            return
        }
        
        guard !documents.isEmpty else {
            completion(false, "Please upload at least one verification document")
            return
        }
        
        isLoading = true
        
        // Check for existing claim first
        checkExistingClaim(for: business.id!) { [weak self] existingClaim in
            guard let self = self else { return }
            
            if existingClaim != nil {
                self.isLoading = false
                completion(false, "You already have a pending claim for this business")
                return
            }
            
            // Create the claim
            let claim = BusinessClaim(
                businessId: business.id!,
                businessName: business.name,
                claimantId: userId,
                claimantName: userProfile.name,
                claimantEmail: userProfile.email,
                status: .pending,
                verificationDocuments: documents,
                additionalNotes: additionalNotes,
                originalOwnerId: business.ownerId,
                originalOwnerName: nil // Will be fetched if needed
            )
            
            // Save to Firestore
            do {
                let _ = try self.db.collection("business_claims").addDocument(from: claim) { error in
                    self.isLoading = false
                    
                    if let error = error {
                        completion(false, "Failed to submit claim: \(error.localizedDescription)")
                        return
                    }
                    
                    // Update business claim status
                    self.updateBusinessClaimStatus(
                        businessId: business.id!,
                        status: "pending"
                    )
                    
                    // Send notification
                    self.notifyAdminsOfNewClaim(claim: claim)
                    
                    completion(true, "✅ Claim submitted successfully! You'll be notified when an admin reviews it.")
                }
            } catch {
                self.isLoading = false
                completion(false, "Failed to submit claim: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Upload Verification Document
    
    /// Upload a verification document to Cloudinary
    func uploadVerificationDocument(
        _ image: UIImage,
        documentType: ClaimVerificationDocument.DocumentType,
        completion: @escaping (ClaimVerificationDocument?) -> Void
    ) {
        isUploadingDocument = true
        uploadProgress = 0
        
        // Simulate progress (since we can't track actual upload progress easily)
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.uploadProgress < 0.9 {
                self.uploadProgress += 0.1
            } else {
                timer.invalidate()
            }
        }
        
        DocumentManager.shared.uploadImage(image.jpegData(compressionQuality: 0.8)!) { result in
            DispatchQueue.main.async {
                self.isUploadingDocument = false
                self.uploadProgress = 1.0
                
                switch result {
                case .success(let url):
                    let document = ClaimVerificationDocument(
                        documentType: documentType,
                        fileURL: url,
                        fileName: "\(documentType.displayName).jpg",
                        uploadedAt: Date(),
                        fileSize: Int64(image.jpegData(compressionQuality: 0.8)?.count ?? 0)
                    )
                    completion(document)
                    
                case .failure(let error):
                    self.errorMessage = "Failed to upload document: \(error.localizedDescription)"
                    completion(nil)
                }
                
                // Reset progress after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.uploadProgress = 0
                }
            }
        }
    }
    
    // MARK: - Cancel Claim
    
    /// Cancel a pending claim
    func cancelClaim(_ claim: BusinessClaim, completion: @escaping (Bool, String) -> Void) {
        guard let claimId = claim.id else {
            completion(false, "Invalid claim ID")
            return
        }
        
        guard claim.canBeCancelled else {
            completion(false, "This claim cannot be cancelled")
            return
        }
        
        isLoading = true
        
        var updatedClaim = claim
        updatedClaim.status = .cancelled
        
        // Add audit entry
        if let userId = Auth.auth().currentUser?.uid {
            updatedClaim.addAuditEntry(
                AuditEntry(
                    action: .cancelled,
                    performedBy: userId,
                    performedByName: claim.claimantName,
                    notes: "Claim cancelled by user"
                )
            )
        }
        
        do {
            try db.collection("business_claims").document(claimId).setData(from: updatedClaim) { [weak self] error in
                self?.isLoading = false
                
                if let error = error {
                    completion(false, "Failed to cancel claim: \(error.localizedDescription)")
                    return
                }
                
                // Update business status back to unclaimed
                self?.updateBusinessClaimStatus(
                    businessId: claim.businessId,
                    status: "unclaimed"
                )
                
                completion(true, "Claim cancelled successfully")
            }
        } catch {
            isLoading = false
            completion(false, "Failed to cancel claim: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Admin Functions
    
    /// Approve a business claim (Admin only)
    func approveClaim(
        _ claim: BusinessClaim,
        adminId: String,
        adminName: String,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let claimId = claim.id else {
            completion(false, "Invalid claim ID")
            return
        }
        
        isLoading = true
        
        var updatedClaim = claim
        updatedClaim.status = .approved
        updatedClaim.reviewedBy = adminId
        updatedClaim.reviewerName = adminName
        updatedClaim.reviewCompletedAt = Date()
        
        // Add audit entry
        updatedClaim.addAuditEntry(
            AuditEntry(
                action: .approved,
                performedBy: adminId,
                performedByName: adminName,
                notes: "Claim approved and ownership transferred"
            )
        )
        
        // Save updated claim
        do {
            try db.collection("business_claims").document(claimId).setData(from: updatedClaim) { [weak self] error in
                if let error = error {
                    self?.isLoading = false
                    completion(false, "Failed to approve claim: \(error.localizedDescription)")
                    return
                }
                
                // Transfer ownership
                self?.transferBusinessOwnership(
                    businessId: claim.businessId,
                    newOwnerId: claim.claimantId,
                    newOwnerName: claim.claimantName,
                    newOwnerEmail: claim.claimantEmail,
                    adminId: adminId,
                    completion: { success, message in
                        self?.isLoading = false
                        
                        if success {
                            // Send notification to claimant
                            self?.notifyClaimantOfApproval(claim: updatedClaim)
                            completion(true, "✅ Claim approved and ownership transferred!")
                        } else {
                            completion(false, message)
                        }
                    }
                )
            }
        } catch {
            isLoading = false
            completion(false, "Failed to approve claim: \(error.localizedDescription)")
        }
    }
    
    /// Reject a business claim (Admin only)
    func rejectClaim(
        _ claim: BusinessClaim,
        adminId: String,
        adminName: String,
        reason: String,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let claimId = claim.id else {
            completion(false, "Invalid claim ID")
            return
        }
        
        guard !reason.isEmpty else {
            completion(false, "Please provide a rejection reason")
            return
        }
        
        isLoading = true
        
        var updatedClaim = claim
        updatedClaim.status = .rejected
        updatedClaim.reviewedBy = adminId
        updatedClaim.reviewerName = adminName
        updatedClaim.rejectionReason = reason
        updatedClaim.reviewCompletedAt = Date()
        
        // Add audit entry
        updatedClaim.addAuditEntry(
            AuditEntry(
                action: .rejected,
                performedBy: adminId,
                performedByName: adminName,
                notes: "Claim rejected: \(reason)"
            )
        )
        
        do {
            try db.collection("business_claims").document(claimId).setData(from: updatedClaim) { [weak self] error in
                self?.isLoading = false
                
                if let error = error {
                    completion(false, "Failed to reject claim: \(error.localizedDescription)")
                    return
                }
                
                // Update business status back to unclaimed
                self?.updateBusinessClaimStatus(
                    businessId: claim.businessId,
                    status: "unclaimed"
                )
                
                // Send notification to claimant
                self?.notifyClaimantOfRejection(claim: updatedClaim)
                
                completion(true, "Claim rejected successfully")
            }
        } catch {
            isLoading = false
            completion(false, "Failed to reject claim: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Update business claim status
    private func updateBusinessClaimStatus(businessId: String, status: String) {
        db.collection("businesses").document(businessId).updateData([
            "claimStatus": status
        ]) { error in
            if let error = error {
                print("Failed to update business claim status: \(error)")
            }
        }
    }
    
    /// Transfer business ownership to claimant
    private func transferBusinessOwnership(
        businessId: String,
        newOwnerId: String,
        newOwnerName: String,
        newOwnerEmail: String,
        adminId: String,
        completion: @escaping (Bool, String) -> Void
    ) {
        // Get current business data
        db.collection("businesses").document(businessId).getDocument { snapshot, error in
            if let error = error {
                completion(false, "Failed to get business data: \(error.localizedDescription)")
                return
            }
            
            guard var business = try? snapshot?.data(as: Business.self) else {
                completion(false, "Failed to parse business data")
                return
            }
            
            // Create ownership history record for previous owner
            let previousOwnerRecord = OwnershipRecord(
                ownerId: business.ownerId,
                ownerName: "Previous Owner", // Could fetch from users collection if needed
                ownerEmail: "",
                startDate: business.createdAt ?? Date(), // You might want to add createdAt to Business model
                endDate: Date(),
                transferType: .created,
                transferredBy: adminId,
                notes: "Original owner before claim"
            )
            
            // Create ownership history record for new owner
            let newOwnerRecord = OwnershipRecord(
                ownerId: newOwnerId,
                ownerName: newOwnerName,
                ownerEmail: newOwnerEmail,
                startDate: Date(),
                endDate: nil,
                transferType: .claimed,
                transferredBy: adminId,
                notes: "Ownership transferred via claim system"
            )
            
            // Update ownership history
            var history = business.ownershipHistory ?? []
            history.append(previousOwnerRecord)
            history.append(newOwnerRecord)
            
            // Update business fields
            business.ownerId = newOwnerId
            business.claimStatus = "claimed"
            business.claimedBy = newOwnerId
            business.claimedAt = Date()
            business.claimApprovedBy = adminId
            business.ownershipHistory = history
            
            // Save updated business
            do {
                try self.db.collection("businesses").document(businessId).setData(from: business) { error in
                    if let error = error {
                        completion(false, "Failed to transfer ownership: \(error.localizedDescription)")
                        return
                    }
                    
                    // Update user profile to mark as business owner
                    self.updateUserBusinessOwnerStatus(userId: newOwnerId, businessId: businessId)
                    
                    completion(true, "Ownership transferred successfully")
                }
            } catch {
                completion(false, "Failed to transfer ownership: \(error.localizedDescription)")
            }
        }
    }
    
    /// Update user to business owner status and add claimed business
    private func updateUserBusinessOwnerStatus(userId: String, businessId: String) {
        db.collection("users").document(userId).getDocument { snapshot, error in
            guard var user = try? snapshot?.data(as: UserProfile.self) else { return }
            
            user.isBusinessOwner = true
            
            // Add to claimed businesses list
            var claimed = user.claimedBusinessIds ?? []
            if !claimed.contains(businessId) {
                claimed.append(businessId)
            }
            user.claimedBusinessIds = claimed
            
            // Update
            try? self.db.collection("users").document(userId).setData(from: user)
        }
    }
    
    // MARK: - Notifications
    
    /// Notify admins of new claim
    private func notifyAdminsOfNewClaim(claim: BusinessClaim) {
        // In production, send push notification or email to admins
        NotificationManager.shared.scheduleLocalNotification(
            title: "New Business Claim",
            body: "\(claim.claimantName) has claimed \(claim.businessName)",
            timeInterval: 1
        )
    }
    
    /// Notify claimant of approval
    private func notifyClaimantOfApproval(claim: BusinessClaim) {
        NotificationManager.shared.scheduleLocalNotification(
            title: "Claim Approved! 🎉",
            body: "Your claim for \(claim.businessName) has been approved!",
            timeInterval: 1
        )
    }
    
    /// Notify claimant of rejection
    private func notifyClaimantOfRejection(claim: BusinessClaim) {
        NotificationManager.shared.scheduleLocalNotification(
            title: "Claim Update",
            body: "Your claim for \(claim.businessName) requires attention",
            timeInterval: 1
        )
    }
}
