import SwiftUI

struct ClaimManagementView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @State private var selectedStatus: ClaimStatus? = .pending
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
        .sheet(item: $showingClaimDetail) { claim in
            ClaimReviewView(claim: claim)
                .environmentObject(adminVM)
        }
    }
    
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
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var searchSortSection: some View {
        HStack(spacing: 12) {
            AdminSearchBar(
                searchText: $adminVM.claimFilter.searchText,
                placeholder: "Search claims..."
            )
            .onChange(of: adminVM.claimFilter.searchText) { _ in
                adminVM.applyClaimFilter()
            }
            
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
}

// MARK: - Status Tab Component (Renamed to avoid conflict)

struct ClaimStatusTab: View {
    let title: String
    let count: Int
    let isSelected: Bool
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? color : Color.secondary)
                        )
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
    }
}

// MARK: - Claim Card Component (Renamed to avoid conflict)

struct AdminClaimCard: View {
    let claim: BusinessClaim
    let onTap: () -> Void
    
    private var isPriority: Bool {
        let daysSinceSubmission = Calendar.current.dateComponents([.day], from: claim.submittedAt, to: Date()).day ?? 0
        return daysSinceSubmission > 5 && claim.status == .pending
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
                        text: claim.status.displayName,
                        color: colorForStatus(claim.status)
                    )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ClaimDetailRow(icon: "envelope.fill", text: claim.claimantEmail)
                    ClaimDetailRow(icon: "calendar", text: formatDate(claim.submittedAt))
                    ClaimDetailRow(icon: "doc.fill", text: "\(claim.verificationDocuments.count) documents")
                    
                    if isPriority {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text("Pending for \(daysSince(claim.submittedAt)) days")
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
    
    private func colorForStatus(_ status: ClaimStatus) -> Color {
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func daysSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }
}

// MARK: - Detail Row Component (Renamed to avoid conflict)

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

// MARK: - Claim Review Detail View

struct ClaimReviewView: View {
    let claim: BusinessClaim
    @EnvironmentObject var adminVM: AdminViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var showingApproveConfirmation = false
    @State private var showingRejectDialog = false
    @State private var rejectionReason = ""
    @State private var adminNotes = ""
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
                    
                    adminNotesSection
                    
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
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Approve Claim", isPresented: $showingApproveConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Approve") {
                    Task {
                        await approveClaim()
                    }
                }
            } message: {
                Text("Are you sure you want to approve this claim? This will transfer business ownership to \(claim.claimantName).")
            }
            .alert("Reject Claim", isPresented: $showingRejectDialog) {
                TextField("Rejection reason (required)", text: $rejectionReason)
                Button("Cancel", role: .cancel) {}
                Button("Reject", role: .destructive) {
                    Task {
                        await rejectClaim()
                    }
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
            
            Text(claim.status.displayName)
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
                ClaimInfoRow(label: "Business Name", value: claim.businessName)
                ClaimInfoRow(label: "Business ID", value: claim.businessId)
                
                if let originalOwner = claim.originalOwnerName {
                    ClaimInfoRow(label: "Current Owner", value: originalOwner)
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
                ClaimInfoRow(label: "Name", value: claim.claimantName)
                ClaimInfoRow(label: "Email", value: claim.claimantEmail)
                ClaimInfoRow(label: "User ID", value: claim.claimantId)
                ClaimInfoRow(label: "Email Verified", value: claim.emailVerified ? "Yes" : "No")
                ClaimInfoRow(label: "Submitted", value: formatDate(claim.submittedAt))
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
            AdminSectionHeader(title: "Verification Documents", icon: "doc.fill")
            
            if claim.verificationDocuments.isEmpty {
                Text("No documents uploaded")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(claim.verificationDocuments, id: \.id) { doc in
                        ClaimDocumentRow(document: doc)
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
    
    private var adminNotesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminSectionHeader(title: "Admin Notes (Internal)", icon: "note")
            
            TextEditor(text: $adminNotes)
                .frame(minHeight: 100)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        }
    }
    
    private var auditTrailSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminSectionHeader(title: "Audit Trail", icon: "clock.arrow.circlepath")
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(claim.auditTrail, id: \.id) { entry in
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
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
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
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red)
                    )
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
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green)
                    )
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
    
    private func iconForStatus(_ status: ClaimStatus) -> String {
        switch status {
        case .pending:
            return "clock.fill"
        case .underReview:
            return "eye.fill"
        case .approved:
            return "checkmark.circle.fill"
        case .rejected:
            return "xmark.circle.fill"
        case .cancelled:
            return "slash.circle.fill"
        }
    }
    
    private func colorForStatus(_ status: ClaimStatus) -> Color {
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Info Row Component (Renamed to avoid conflict)

struct ClaimInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.body)
        }
    }
}

// MARK: - Document Row Component (Renamed to avoid conflict + Fixed URL)

struct ClaimDocumentRow: View {
    let document: ClaimVerificationDocument
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: documentIcon(for: document.documentType))
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.documentType.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Uploaded \(timeAgo(from: document.uploadedAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                // ✅ FIXED: Use fileURL instead of documentURL
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }
    
    private func documentIcon(for type: ClaimVerificationDocument.DocumentType) -> String {
        return type.icon
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        
        if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }
}
