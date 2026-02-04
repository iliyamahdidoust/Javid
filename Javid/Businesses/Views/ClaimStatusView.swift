import SwiftUI

struct ClaimStatusView: View {
    @StateObject private var viewModel = ClaimBusinessViewModel()
    @State private var showingCancelConfirmation = false
    @State private var claimToCancel: BusinessClaim?
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.claims.isEmpty {
                    emptyStateView
                } else {
                    claimsList
                }
            }
            .navigationTitle("My Claims")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.fetchUserClaims()
            }
            .confirmationDialog(
                "Cancel Claim",
                isPresented: $showingCancelConfirmation,
                titleVisibility: .visible
            ) {
                Button("Cancel Claim", role: .destructive) {
                    if let claim = claimToCancel {
                        cancelClaim(claim)
                    }
                }
                Button("Keep Claim", role: .cancel) {}
            } message: {
                Text("Are you sure you want to cancel this claim? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading your claims...")
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Claims Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("You haven't submitted any business claims. Find a business and claim it to get started!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Claims List
    
    private var claimsList: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(viewModel.claims) { claim in
                    ClaimCardView(claim: claim) {
                        if claim.status.isCancellable {
                            claimToCancel = claim
                            showingCancelConfirmation = true
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Actions
    
    private func cancelClaim(_ claim: BusinessClaim) {
        viewModel.cancelClaim(claim) { success, message in
            // Could show alert here if needed
            print(message)
        }
    }
}

// MARK: - Claim Card Component

struct ClaimCardView: View {
    let claim: BusinessClaim
    let onCancelTapped: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection
            
            // Expandable Details
            if isExpanded {
                Divider()
                    .padding(.vertical, 12)
                
                detailsSection
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Business Name & Status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(claim.businessName)
                        .font(.headline)
                    
                    Text("Submitted \(claim.formattedSubmissionDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                statusBadge
            }
            
            // Status Description
            Text(descriptionForStatus(claim.status))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Progress Indicator
            progressIndicator
            
            // Action Buttons
            actionButtons
        }
    }
    
    // MARK: - Status Badge
    
    private var statusBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: iconForStatus(claim.status))
                .font(.caption)
            
            Text(displayNameForStatus(claim.status))
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.15))
        .foregroundColor(statusColor)
        .cornerRadius(20)
    }
    
    private var statusColor: Color {
        switch claim.status {
        case .pending: return .orange
        case .underReview: return .blue
        case .approved: return .green
        case .rejected: return .red
        case .cancelled: return .gray
        }
    }
    
    // MARK: - Helper Functions for BusinessClaimStatus
    
    private func displayNameForStatus(_ status: BusinessClaimStatus) -> String {
        switch status {
        case .pending: return "Pending Review"
        case .underReview: return "Under Review"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .cancelled: return "Cancelled"
        }
    }
    
    private func iconForStatus(_ status: BusinessClaimStatus) -> String {
        switch status {
        case .pending: return "clock.fill"
        case .underReview: return "magnifyingglass.circle.fill"
        case .approved: return "checkmark.seal.fill"
        case .rejected: return "xmark.circle.fill"
        case .cancelled: return "minus.circle.fill"
        }
    }
    
    private func descriptionForStatus(_ status: BusinessClaimStatus) -> String {
        switch status {
        case .pending:
            return "Your claim has been submitted and is waiting for admin review."
        case .underReview:
            return "An administrator is currently reviewing your claim and verification documents."
        case .approved:
            return "Congratulations! Your claim has been approved and you are now the owner of this business."
        case .rejected:
            return "Your claim has been rejected. Please check the rejection reason and submit a new claim if needed."
        case .cancelled:
            return "This claim was cancelled before review completion."
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack(spacing: 0) {
            let statuses: [BusinessClaimStatus] = [.pending, .underReview, .approved]
            
            ForEach(Array(statuses.enumerated()), id: \.offset) { index, status in
                progressStep(status: status, isLast: index == statuses.count - 1)
            }
        }
    }
    
    private func progressStep(status: BusinessClaimStatus, isLast: Bool) -> some View {
        let isActive = statusIndex(claim.status) >= statusIndex(status)
        let isCurrent = claim.status == status
        
        return HStack(spacing: 0) {
            // Circle
            Circle()
                .fill(isActive ? statusColor : Color.gray.opacity(0.3))
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(isCurrent ? statusColor : Color.clear, lineWidth: 2)
                        .frame(width: 16, height: 16)
                )
            
            // Line (if not last)
            if !isLast {
                Rectangle()
                    .fill(isActive ? statusColor.opacity(0.5) : Color.gray.opacity(0.3))
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func statusIndex(_ status: BusinessClaimStatus) -> Int {
        switch status {
        case .pending: return 0
        case .underReview: return 1
        case .approved: return 2
        case .rejected: return 2
        case .cancelled: return -1
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    Text(isExpanded ? "Hide Details" : "View Details")
                        .fontWeight(.medium)
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            Spacer()
            
            if claim.status.isCancellable {
                Button(action: onCancelTapped) {
                    Text("Cancel Claim")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Documents
            if !claim.verificationDocuments.isEmpty {
                documentsList
            }
            
            // Additional Notes
            if let notes = claim.additionalNotes, !notes.isEmpty {
                notesSection(notes)
            }
            
            // Rejection Reason (if applicable)
            if let reason = claim.rejectionReason, !reason.isEmpty {
                rejectionReasonSection(reason)
            }
            
            // Audit Trail
            auditTrailSection
            
            // Timeline Info
            timelineInfo
        }
    }
    
    // MARK: - Documents List
    
    private var documentsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Verification Documents")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            ForEach(claim.verificationDocuments) { document in
                HStack(spacing: 12) {
                    Image(systemName: document.documentType.icon)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(document.documentType.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text(document.formattedFileSize)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Notes Section
    
    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Notes")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(notes)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
    
    // MARK: - Rejection Reason Section
    
    private func rejectionReasonSection(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Rejection Reason", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.red)
            
            Text(reason)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    // MARK: - Audit Trail
    
    private var auditTrailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity History")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            ForEach(claim.auditTrail.sorted(by: { $0.timestamp > $1.timestamp })) { entry in
                auditEntryRow(entry)
            }
        }
    }
    
    private func auditEntryRow(_ entry: AuditEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.action.icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.action.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if let notes = entry.notes {
                    Text(notes)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(entry.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Timeline Info
    
    private var timelineInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 4) {
                timelineRow(label: "Submitted", date: claim.submittedAt)
                
                if let reviewStarted = claim.reviewStartedAt {
                    timelineRow(label: "Review Started", date: reviewStarted)
                }
                
                if let reviewCompleted = claim.reviewCompletedAt {
                    timelineRow(label: "Review Completed", date: reviewCompleted)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private func timelineRow(label: String, date: Date) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(date, style: .date)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

struct ClaimStatusView_Previews: PreviewProvider {
    static var previews: some View {
        ClaimStatusView()
    }
}
