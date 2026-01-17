import SwiftUI

struct SavedJobsView: View {
    @StateObject private var jobViewModel = JobViewModel()
    @State private var savedJobs: [Job] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedSort: SortOption = .newest
    
    enum SortOption: String, CaseIterable {
        case newest = "Newest First"
        case oldest = "Oldest First"
        case highestSalary = "Highest Salary"
        case lowestSalary = "Lowest Salary"
    }
    
    var filteredAndSortedJobs: [Job] {
        var jobs = savedJobs
        
        // Filter by search
        if !searchText.isEmpty {
            jobs = jobs.filter { job in
                job.title.localizedCaseInsensitiveContains(searchText) ||
                job.company.localizedCaseInsensitiveContains(searchText) ||
                job.location.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort
        switch selectedSort {
        case .newest:
            jobs.sort { $0.createdAt > $1.createdAt }
        case .oldest:
            jobs.sort { $0.createdAt < $1.createdAt }
        case .highestSalary:
            jobs.sort { ($0.salaryMax ?? 0) > ($1.salaryMax ?? 0) }
        case .lowestSalary:
            jobs.sort { ($0.salaryMin ?? 0) < ($1.salaryMin ?? 0) }
        }
        
        return jobs
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search saved jobs...", text: $searchText)
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
            
            // Sort Options
            HStack {
                Text("Sort by:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button(action: { selectedSort = option }) {
                            HStack {
                                Text(option.rawValue)
                                if selectedSort == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedSort.rawValue)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                Text("\(filteredAndSortedJobs.count) Saved")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            Divider()
            
            // Jobs List
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredAndSortedJobs.isEmpty {
                EmptySavedJobsView(hasSearch: !searchText.isEmpty)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredAndSortedJobs) { job in
                            SavedJobCard(job: job) {
                                if let index = savedJobs.firstIndex(where: { $0.id == job.id }) {
                                    savedJobs.remove(at: index)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Saved Jobs")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadSavedJobs()
        }
        .refreshable {
            loadSavedJobs()
        }
    }
    
    private func loadSavedJobs() {
        isLoading = true
        // Fetch saved jobs from JobViewModel
        Task {
            // This would need to be implemented in JobViewModel
            // For now, using a placeholder
            savedJobs = []
            isLoading = false
        }
    }
}

struct SavedJobCard: View {
    let job: Job
    let onUnsave: () -> Void
    
    @State private var showingJobDetail = false
    @State private var showingUnsaveAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with unsave button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(job.title)
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        Text(job.company)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if job.employerVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: { showingUnsaveAlert = true }) {
                    Image(systemName: "bookmark.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            
            // Location and Work Mode
            HStack(spacing: 12) {
                Label(job.location, systemImage: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if job.workMode != .onSite {
                    Label(job.workMode.rawValue, systemImage: job.workMode.icon)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // Salary
            if let salaryMin = job.salaryMin, let salaryMax = job.salaryMax,
               salaryMin > 0 || salaryMax > 0 {
                Text(salaryText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            
            // Tags
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    TagView(text: job.category.rawValue, color: .blue)
                    TagView(text: job.jobType.rawValue, color: .orange)
                    TagView(text: job.experienceLevel.rawValue, color: .purple)
                }
            }
            
            // Footer
            HStack {
                Label(timeAgoText, systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { showingJobDetail = true }) {
                    Text("View Details")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingJobDetail) {
            NavigationView {
                JobDetailView(job: job)
            }
        }
        .alert("Remove from Saved?", isPresented: $showingUnsaveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                onUnsave()
            }
        } message: {
            Text("This job will be removed from your saved jobs.")
        }
    }
    
    private var salaryText: String {
        let salaryMin = job.salaryMin ?? 0
        let salaryMax = job.salaryMax ?? 0
        
        if salaryMin > 0 && salaryMax > 0 {
            return "\(job.salaryCurrency)\(Int(salaryMin).formatted()) - \(job.salaryCurrency)\(Int(salaryMax).formatted())/\(job.salaryPeriod.rawValue)"
        } else if salaryMin > 0 {
            return "\(job.salaryCurrency)\(Int(salaryMin).formatted())+/\(job.salaryPeriod.rawValue)"
        } else if salaryMax > 0 {
            return "Up to \(job.salaryCurrency)\(Int(salaryMax).formatted())/\(job.salaryPeriod.rawValue)"
        }
        return ""
    }
    
    private var timeAgoText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: job.createdAt, relativeTo: Date())
    }
}

struct TagView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

struct EmptySavedJobsView: View {
    let hasSearch: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: hasSearch ? "magnifyingglass" : "bookmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(hasSearch ? "No matching jobs" : "No saved jobs yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(hasSearch ? "Try adjusting your search" : "Bookmark jobs you're interested in to save them here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if !hasSearch {
                NavigationLink(destination: JobsBrowseView()) {
                    Text("Browse Jobs")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
