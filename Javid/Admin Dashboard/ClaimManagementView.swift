//
//  ClaimManagementView.swift
//  Javid Admin Panel
//
//  Complete claim management with review workflow
//

import SwiftUI

struct ClaimManagementView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @State private var selectedStatus: BusinessClaimStatus? = .pending
    @State private var showingClaimDetail: BusinessClaim?
    @State private var sortBy: ClaimSortOption = .submittedDate
    
    enum ClaimSortOption: String, CaseIterable {
        case submittedDate = "Submission Date"
        case businessName = "Business Name"
        case claimantName = "Claimant Name"
        case status = "Status"
    }
    
    var filteredClaims: [BusinessClaim] {
        var claims = adminVM.filteredClaims
        
        if let status = selectedStatus {
            claims = claims.filter { $0.status == status }
        }
        
        return claims.sorted { c1, c2 in
            switch sortBy {
            case .submittedDate:
                return c1.submittedAt > c2.submittedAt
            case .businessName:
                return c1.businessName < c2.businessName
            case .claimantName:
                return c1.claimantName < c2.claimantName
            case .status:
                return c1.status.rawValue < c2.status.rawValue
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            statusFilterSection
            searchSortSection
            
            if adminVM.isLoading {
                LoadingView(message: "Loading claims...")
            } else if filteredClaims.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "No Claims Found",
                    message: selectedStatus == .pending ?
                        "No pending claims at the moment" :
                        "No claims with this status"
                )
            } else {
                claimsListSection
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Business Claims")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $showingClaimDetail) { claim in
            ClaimReviewView(claim: claim)
                .environmentObject(adminVM)
        }
    }
    
    // MARK: - Status Filter
    
    private var statusFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ClaimStatusTab(
                    title: "All",
                    count: adminVM.allClaims.count,
                    isSelected: selectedStatus == nil
                ) {
                    selectedStatus = nil
                }
                
                ClaimStatusTab(
                    title: "Pending",
                    count: adminVM.allClaims.filter { $0.status == .pending }.count,
                    isSelected: selectedStatus == .pending,
                    color: .orange
                ) {
                    selectedStatus = .pending
                }
                
                ClaimStatusTab(
                    title: "Under Review",
                    count: adminVM.allClaims.filter { $0.status == .underReview }.count,
                    isSelected: selectedStatus == .underReview,
                    color: .blue
                ) {
                    selectedStatus = .underReview
                }
                
                ClaimStatusTab(
                    title: "Approved",
                    count: adminVM.allClaims.filter { $0.status == .approved }.count,
                    isSelected: selectedStatus == .approved,
                    color: .green
                ) {
                    selectedStatus = .approved
                }
                
                ClaimStatusTab(
                    title: "Rejected",
                    count: adminVM.allClaims.filter { $0.status == .rejected }.count,
                    isSelected: selectedStatus == .rejected,
                    color: .red
                ) {
                    selectedStatus = .rejected
                }
                
                ClaimStatusTab(
                    title: "Cancelled",
                    count: adminVM.allClaims.filter { $0.status == .cancelled }.count,
                    isSelected: selectedStatus == .cancelled,
                    color: .gray
                ) {
                    selectedStatus = .cancelled
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Search & Sort
    
    private var searchSortSection: some View {
        HStack(spacing: 12) {
            AdminSearchBar(
                searchText: $adminVM.claimFilter.searchText,
                placeholder: "Search claims..."
            )
            
            Menu {
                ForEach(ClaimSortOption.allCases, id: \.self) { option in
                    Button(action: { sortBy = option }) {
                        HStack {
                            Text(option.rawValue)
                            if sortBy == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.subheadline)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                    )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    // MARK: - Claims List
    
    private var claimsListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredClaims) { claim in
                    AdminClaimCard(claim: claim) {
                        showingClaimDetail = claim
                    }
                }
            }
            .padding()
        }
    }
    
    private func colorForStatus(_ status: BusinessClaimStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .underReview:
            return .blue
        case .approved:
            return .green
        case .rejected:
            return .red
        case .cancelled:
            return .gray
        }
    }
    
    private func displayNameForStatus(_ status: BusinessClaimStatus) -> String {
        switch status {
        case .pending: return "Pending"
        case .underReview: return "Under Review"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .cancelled: return "Cancelled"
        }
    }
}

// MARK: - Status Tab

struct ClaimStatusTab: View {
    let title: String
    let count: Int
    let isSelected: Bool
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(isSelected ? color : Color.secondary))
                }
                .foregroundColor(isSelected ? color : .secondary)
                
                if isSelected {
                    Rectangle()
                        .fill(color)
                        .frame(height: 3)
                        .cornerRadius(1.5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Claim Card

struct AdminClaimCard: View {
    let claim: BusinessClaim
    let onTap: () -> Void
    
    private var isPriority: Bool {
        claim.daysSinceSubmission > 5 && claim.status == .pending
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(claim.businessName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(claim.claimantName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    AdminStatusBadge(
                        text: displayNameForStatus(claim.status),
                        color: colorForStatus(claim.status)
                    )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ClaimDetailRow(icon: "envelope.fill", text: claim.claimantEmail)
                    ClaimDetailRow(icon: "calendar", text: formatDate(claim.submittedAt))
                    ClaimDetailRow(icon: "doc.fill", text: "\(claim.verificationDocuments.count) documents")
                    
                    if claim.emailVerified {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("Email Verified")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    if isPriority {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text("Pending for \(claim.daysSinceSubmission) days")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.orange)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.orange.opacity(0.1))
                        )
                    }
                }
                
                if claim.status == .pending || claim.status == .underReview {
                    HStack(spacing: 8) {
                        Text("Tap to review")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(isPriority ? 0.1 : 0.05), radius: 5, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isPriority ? Color.orange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func colorForStatus(_ status: BusinessClaimStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .underReview:
            return .blue
        case .approved:
            return .green
        case .rejected:
            return .red
        case .cancelled:
            return .gray
        }
    }
    
    private func displayNameForStatus(_ status: BusinessClaimStatus) -> String {
        switch status {
        case .pending: return "Pending"
        case .underReview: return "Under Review"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .cancelled: return "Cancelled"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Detail Row

struct ClaimDetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Claim Review View

struct ClaimReviewView: View {
    let claim: BusinessClaim
    @EnvironmentObject var adminVM: AdminViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var showingApproveConfirmation = false
    @State private var showingRejectDialog = false
    @State private var rejectionReason = ""
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    statusBanner
                    businessInfoSection
                    claimantInfoSection
                    documentsSection
                    
                    if let notes = claim.additionalNotes, !notes.isEmpty {
                        notesSection(notes)
                    }
                    
                    if !claim.auditTrail.isEmpty {
                        auditTrailSection
                    }
                    
                    if claim.status == .pending || claim.status == .underReview {
                        actionButtonsSection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Claim Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Approve Claim", isPresented: $showingApproveConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Approve") {
                    Task { await approveClaim() }
                }
            } message: {
                Text("Are you sure you want to approve this claim? This will transfer business ownership to \(claim.claimantName).")
            }
            .alert("Reject Claim", isPresented: $showingRejectDialog) {
                TextField("Rejection reason (required)", text: $rejectionReason)
                Button("Cancel", role: .cancel) {}
                Button("Reject", role: .destructive) {
                    Task { await rejectClaim() }
                }
                .disabled(rejectionReason.isEmpty)
            } message: {
                Text("Please provide a reason for rejecting this claim. This will be sent to the claimant.")
            }
            .disabled(isProcessing)
        }
    }
    
    private var statusBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: iconForStatus(claim.status))
                .font(.system(size: 48))
                .foregroundColor(colorForStatus(claim.status))
            
            Text(displayNameForStatus(claim.status))
                .font(.title2)
                .fontWeight(.bold)
            
            if let reviewerName = claim.reviewerName {
                Text("Reviewed by \(reviewerName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorForStatus(claim.status).opacity(0.1))
        )
    }
    
    private var businessInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminSectionHeader(title: "Business Information", icon: "building.2.fill")
            
            VStack(alignment: .leading, spacing: 12) {
                AdminInfoRow(icon: "building.2", title: "Business Name", subtitle: claim.businessName)
                AdminInfoRow(icon: "number", title: "Business ID", subtitle: claim.businessId)
                
                if let originalOwner = claim.originalOwnerName {
                    AdminInfoRow(icon: "person", title: "Original Owner", subtitle: originalOwner)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
        }
    }
    
    private var claimantInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminSectionHeader(title: "Claimant Information", icon: "person.fill")
            
            VStack(alignment: .leading, spacing: 12) {
                AdminInfoRow(icon: "person", title: "Name", subtitle: claim.claimantName)
                AdminInfoRow(icon: "envelope", title: "Email", subtitle: claim.claimantEmail)
                AdminInfoRow(icon: "number", title: "User ID", subtitle: claim.claimantId)
                AdminInfoRow(icon: "checkmark.seal", title: "Email Verified", subtitle: claim.emailVerified ? "Yes" : "No")
                AdminInfoRow(icon: "calendar", title: "Submitted", subtitle: claim.formattedSubmissionDate)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
        }
    }
    
    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminSectionHeader(title: "Verification Documents (\(claim.verificationDocuments.count))", icon: "doc.fill")
            
            if claim.verificationDocuments.isEmpty {
                Text("No documents uploaded")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(claim.verificationDocuments) { doc in
                        AdminDocumentRow(document: doc)
                    }
                }
            }
        }
    }
    
    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminSectionHeader(title: "Claimant Notes", icon: "note.text")
            
            Text(notes)
                .font(.body)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                )
        }
    }
    
    private var auditTrailSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminSectionHeader(title: "Audit Trail", icon: "clock.arrow.circlepath")
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(claim.auditTrail.sorted { $0.timestamp > $1.timestamp }) { entry in
                    AuditEntryRow(entry: entry)
                }
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: { showingRejectDialog = true }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Reject")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.red))
                    .foregroundColor(.white)
                }
                
                Button(action: { showingApproveConfirmation = true }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Approve")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.green))
                    .foregroundColor(.white)
                }
            }
        }
        .padding(.top)
    }
    
    private func approveClaim() async {
        isProcessing = true
        do {
            try await adminVM.approveClaim(claim)
            dismiss()
        } catch {
            adminVM.errorMessage = error.localizedDescription
        }
        isProcessing = false
    }
    
    private func rejectClaim() async {
        isProcessing = true
        do {
            try await adminVM.rejectClaim(claim, reason: rejectionReason)
            dismiss()
        } catch {
            adminVM.errorMessage = error.localizedDescription
        }
        isProcessing = false
    }
    
    private func iconForStatus(_ status: BusinessClaimStatus) -> String {
        switch status {
        case .pending: return "clock.fill"
        case .underReview: return "eye.fill"
        case .approved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .cancelled: return "slash.circle.fill"
        }
    }
    
    private func colorForStatus(_ status: BusinessClaimStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .underReview: return .blue
        case .approved: return .green
        case .rejected: return .red
        case .cancelled: return .gray
        }
    }
    
    private func displayNameForStatus(_ status: BusinessClaimStatus) -> String {
        switch status {
        case .pending: return "Pending"
        case .underReview: return "Under Review"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .cancelled: return "Cancelled"
        }
    }
}

// MARK: - Document Row

struct AdminDocumentRow: View {
    let document: ClaimVerificationDocument
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: document.documentType.icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.1)))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.documentType.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(document.formattedFileSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                if let url = URL(string: document.fileURL) {
                    UIApplication.shared.open(url)
                }
            }) {
                Image(systemName: "arrow.up.right.square")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
    }
}

// MARK: - Audit Entry Row

struct AuditEntryRow: View {
    let entry: AuditEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.action.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("By \(entry.performedByName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatDate(entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let notes = entry.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
