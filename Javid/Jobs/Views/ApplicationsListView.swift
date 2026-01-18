import SwiftUI

struct ApplicationsListView: View {
    let jobId: String
    let jobTitle: String
    @StateObject private var viewModel = JobApplicationViewModel()
    @State private var selectedFilter: ApplicationStatus?
    @State private var searchText = ""
    @State private var selectedApplication: JobApplication?
    @State private var showingApplicationDetail = false
    
    var filteredApplications: [JobApplication] {
        var apps = viewModel.applications
        
        if let status = selectedFilter {
            apps = apps.filter { $0.status == status }
        }
        
        if !searchText.isEmpty {
            apps = apps.filter { app in
                app.applicantName.localizedCaseInsensitiveContains(searchText) ||
                app.applicantEmail.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return apps.sorted { $0.appliedAt > $1.appliedAt }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text(jobTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("\(filteredApplications.count) Applications")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search applicants...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .padding()
            
            // Status Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ApplicationFilterChip(
                        title: "All",
                        count: viewModel.applications.count,
                        isSelected: selectedFilter == nil,
                        action: { selectedFilter = nil }
                    )
                    
                    ForEach(ApplicationStatus.allCases, id: \.self) { status in
                        ApplicationFilterChip(
                            title: status.rawValue,
                            count: viewModel.applications.filter { $0.status == status }.count,
                            isSelected: selectedFilter == status,
                            action: { selectedFilter = status }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
            
            Divider()
            
            // Applications List
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredApplications.isEmpty {
                EmptyApplicationsView(hasFilter: selectedFilter != nil || !searchText.isEmpty)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredApplications) { application in
                            ApplicationCardView(application: application)
                                .onTapGesture {
                                    selectedApplication = application
                                    showingApplicationDetail = true
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Applications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchApplicationsForJob(jobId: jobId) { apps in
                // Completion handler
            }
        }
        .sheet(item: $selectedApplication) { application in
            ApplicationDetailSheet(application: application)
        }
    }
}

// Renamed to avoid conflict with FilterChip.swift
struct ApplicationFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text("\(count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// Renamed to avoid conflict with other files
struct ApplicationCardView: View {
    let application: JobApplication
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(application.applicantName)
                        .font(.headline)
                    
                    Text(application.applicantEmail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusBadge(status: application.status)
            }
            
            // Cover Letter Preview
            if !application.coverLetter.isEmpty {
                Text(application.coverLetter)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Metadata
            HStack {
                Label(formatDate(application.appliedAt), systemImage: "calendar")
                
                Spacer()
                
                if application.resumeURL != nil {
                    Label("Resume", systemImage: "doc.fill")
                }
                
                if !application.portfolioURLs.isEmpty {
                    Label("\(application.portfolioURLs.count) Files", systemImage: "folder.fill")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct StatusBadge: View {
    let status: ApplicationStatus
    
    var backgroundColor: Color {
        switch status {
        case .pending: return .orange
        case .reviewed: return .blue
        case .shortlisted: return .purple
        case .interview: return .cyan
        case .offered: return .green
        case .rejected: return .red
        case .withdrawn: return .gray
        }
    }
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.2))
            .foregroundColor(backgroundColor)
            .cornerRadius(8)
    }
}

struct EmptyApplicationsView: View {
    let hasFilter: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasFilter ? "line.3.horizontal.decrease.circle" : "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(hasFilter ? "No matching applications" : "No applications yet")
                .font(.headline)
            
            Text(hasFilter ? "Try adjusting your filters" : "Applications will appear here when candidates apply")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// Renamed to avoid conflict
struct ApplicationDetailSheet: View {
    let application: JobApplication
    @StateObject private var viewModel = JobApplicationViewModel()
    @StateObject private var messagingViewModel = JobMessagingViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showingStatusMenu = false
    @State private var showingMessageComposer = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Applicant Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text(application.applicantName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Label(application.applicantEmail, systemImage: "envelope")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if !application.applicantPhone.isEmpty {
                            Label(application.applicantPhone, systemImage: "phone")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        StatusBadge(status: application.status)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Cover Letter
                    if !application.coverLetter.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cover Letter")
                                .font(.headline)
                            
                            Text(application.coverLetter)
                                .font(.body)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    
                    // Custom Answers
                    if !application.customAnswers.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Application Answers")
                                .font(.headline)
                            
                            ForEach(Array(application.customAnswers.keys.sorted()), id: \.self) { question in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(question)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text(application.customAnswers[question] ?? "")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    
                    // Documents
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Documents")
                            .font(.headline)
                        
                        if let resumeURL = application.resumeURL {
                            DocumentRow(title: "Resume", url: resumeURL)
                        }
                        
                        ForEach(application.portfolioURLs, id: \.self) { url in
                            DocumentRow(title: "Portfolio Document", url: url)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button(action: { showingStatusMenu = true }) {
                            Label("Change Status", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        
                        Button(action: { showingMessageComposer = true }) {
                            Label("Send Message", systemImage: "message")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Application Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Change Status", isPresented: $showingStatusMenu) {
                ForEach(ApplicationStatus.allCases, id: \.self) { status in
                    Button(status.rawValue) {
                        // Fixed: Using correct method signature
                        viewModel.updateApplicationStatus(
                            application,
                            status: status
                        ) { success, message in
                            alertMessage = message
                            showAlert = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingMessageComposer) {
                MessageComposerView(
                    recipientId: application.applicantId,
                    recipientName: application.applicantName,
                    jobId: application.jobId,
                    applicationId: application.id ?? ""
                )
            }
            .alert("Status Update", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }
}

struct DocumentRow: View {
    let title: String
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundColor(.blue)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
    }
}

struct MessageComposerView: View {
    let recipientId: String
    let recipientName: String
    let jobId: String
    let applicationId: String
    
    @StateObject private var viewModel = JobMessagingViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var messageText = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Send message to \(recipientName)")
                    .font(.headline)
                    .padding()
                
                TextEditor(text: $messageText)
                    .frame(height: 200)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding()
                
                Spacer()
                
                Button(action: sendMessage) {
                    Text("Send Message")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(messageText.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(messageText.isEmpty)
                .padding()
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Message", isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    if alertMessage.contains("✅") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func sendMessage() {
        // Fixed: Using correct method signature
        let conversationId = "\(jobId)_\(recipientId)"
        
        viewModel.sendMessage(
            conversationId: conversationId,
            jobId: jobId,
            applicationId: applicationId,
            recipientId: recipientId,
            recipientName: recipientName,
            message: messageText
        ) { success, message in
            alertMessage = message
            showAlert = true
        }
    }
}
