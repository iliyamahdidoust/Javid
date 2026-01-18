import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
import Combine

class JobViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var jobs: [Job] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage = ""
    @Published var hasMoreData = true
    @Published var savedJobIds: Set<String> = []
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var lastDocument: DocumentSnapshot?
    private let pageSize = 15
    private var jobsListener: ListenerRegistration?
    private var savesListener: ListenerRegistration?
    
    // Location for distance sorting
    var userLocation: CLLocation?
    
    // Cache
    private var jobsCache: [Job] = []
    private var cacheTimestamp: Date?
    private let cacheValidDuration: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    init() {
        setupRealtimeListener()
        fetchUserSavedJobs()
    }
    
    deinit {
        jobsListener?.remove()
        savesListener?.remove()
    }
    
    // MARK: - Real-time Listener
    private func setupRealtimeListener() {
        guard !isLoading else { return }
        
        isLoading = true
        
        var query: Query = db.collection("jobs")
            .whereField("isActive", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)
        
        jobsListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = "Failed to load jobs: \(error.localizedDescription)"
                print("❌ Error fetching jobs: \(error)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No jobs found")
                self.hasMoreData = false
                return
            }
            
            // Update only changes
            snapshot?.documentChanges.forEach { change in
                if let job = try? change.document.data(as: Job.self) {
                    switch change.type {
                    case .added:
                        if !self.jobs.contains(where: { $0.id == job.id }) {
                            self.jobs.append(job)
                        }
                    case .modified:
                        if let index = self.jobs.firstIndex(where: { $0.id == job.id }) {
                            self.jobs[index] = job
                        }
                    case .removed:
                        self.jobs.removeAll { $0.id == job.id }
                    }
                }
            }
            
            self.lastDocument = documents.last
            self.hasMoreData = documents.count == self.pageSize
            
            print("✅ Loaded \(self.jobs.count) jobs")
        }
    }
    
    // MARK: - Fetch Jobs
    func fetchJobs() {
        // Check cache first
        if let cacheTimestamp = cacheTimestamp,
           Date().timeIntervalSince(cacheTimestamp) < cacheValidDuration,
           !jobsCache.isEmpty {
            self.jobs = jobsCache
            print("✅ Loaded from cache: \(jobs.count) jobs")
            return
        }
        
        guard !isLoading else { return }
        
        isLoading = true
        lastDocument = nil
        
        var query: Query = db.collection("jobs")
            .whereField("isActive", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)
        
        query.getDocuments { [weak self] snapshot, error in
            self?.isLoading = false
            
            if let error = error {
                self?.errorMessage = "Failed to load jobs: \(error.localizedDescription)"
                print("❌ Error fetching jobs: \(error)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No jobs found")
                self?.hasMoreData = false
                return
            }
            
            self?.jobs = documents.compactMap { doc -> Job? in
                try? doc.data(as: Job.self)
            }
            
            // Update cache
            self?.jobsCache = self?.jobs ?? []
            self?.cacheTimestamp = Date()
            
            self?.lastDocument = documents.last
            self?.hasMoreData = documents.count == self?.pageSize
            
            print("✅ Loaded \(self?.jobs.count ?? 0) jobs")
        }
    }
    
    // MARK: - Load More (Pagination)
    func loadMoreJobs() {
        guard !isLoadingMore,
              !isLoading,
              hasMoreData,
              let lastDoc = lastDocument else {
            return
        }
        
        isLoadingMore = true
        
        var query: Query = db.collection("jobs")
            .whereField("isActive", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .start(afterDocument: lastDoc)
            .limit(to: pageSize)
        
        query.getDocuments { [weak self] snapshot, error in
            self?.isLoadingMore = false
            
            if let error = error {
                print("❌ Error loading more: \(error)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                self?.hasMoreData = false
                return
            }
            
            let newJobs = documents.compactMap { doc -> Job? in
                try? doc.data(as: Job.self)
            }
            
            self?.jobs.append(contentsOf: newJobs)
            
            // Update cache
            self?.jobsCache = self?.jobs ?? []
            self?.cacheTimestamp = Date()
            
            self?.lastDocument = documents.last
            self?.hasMoreData = documents.count == self?.pageSize
            
            print("✅ Loaded \(newJobs.count) more jobs. Total: \(self?.jobs.count ?? 0)")
        }
    }
    
    // MARK: - Refresh
    func refreshJobs() {
        // Clear cache
        jobsCache = []
        cacheTimestamp = nil
        
        jobs = []
        lastDocument = nil
        hasMoreData = true
        
        // Remove old listener
        jobsListener?.remove()
        
        // Setup new listener
        setupRealtimeListener()
    }
    
    // MARK: - Add Job
    func addJob(_ job: Job, completion: @escaping (Bool, String) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false, "You must be logged in to post a job")
            return
        }
        
        var newJob = job
        newJob.employerId = userId
        
        do {
            try db.collection("jobs").document(job.id ?? UUID().uuidString).setData(from: newJob) { error in
                if let error = error {
                    completion(false, "Failed to post job: \(error.localizedDescription)")
                } else {
                    completion(true, "✅ Job posted successfully!")
                }
            }
        } catch {
            completion(false, "Failed to encode job data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Update Job
    func updateJob(_ job: Job, completion: @escaping (Bool, String) -> Void) {
        guard let jobId = job.id else {
            completion(false, "Invalid job ID")
            return
        }
        
        var updatedJob = job
        updatedJob.updatedAt = Date()
        
        do {
            try db.collection("jobs").document(jobId).setData(from: updatedJob) { error in
                if let error = error {
                    completion(false, "Failed to update job: \(error.localizedDescription)")
                } else {
                    completion(true, "✅ Job updated successfully!")
                }
            }
        } catch {
            completion(false, "Failed to encode job data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Delete Job
    func deleteJob(_ job: Job, completion: @escaping (Bool, String) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false, "You must be logged in")
            return
        }
        
        guard let jobId = job.id else {
            completion(false, "Invalid job ID")
            return
        }
        
        guard job.employerId == userId else {
            completion(false, "You can only delete your own jobs")
            return
        }
        
        db.collection("jobs").document(jobId).delete { error in
            if let error = error {
                completion(false, "Failed to delete job: \(error.localizedDescription)")
            } else {
                completion(true, "✅ Job deleted successfully!")
            }
        }
    }
    
    // MARK: - Increment View Count
    func incrementViewCount(for jobId: String) {
        db.collection("jobs").document(jobId).updateData([
            "viewCount": FieldValue.increment(Int64(1))
        ])
    }
    
    // MARK: - Get Employer Jobs
    func getEmployerJobs() -> [Job] {
        guard let userId = Auth.auth().currentUser?.uid else {
            return []
        }
        return jobs.filter { $0.employerId == userId }
    }
    
    // MARK: - Saved Jobs
    func fetchUserSavedJobs() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            return
        }
        
        // Remove previous listener
        savesListener?.remove()
        
        // Add real-time listener for saved jobs
        savesListener = db.collection("job_saves")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error fetching saved jobs: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No saved jobs found")
                    return
                }
                
                let saves = documents.compactMap { doc -> JobSave? in
                    try? doc.data(as: JobSave.self)
                }
                
                // Create Set for fast lookup
                self?.savedJobIds = Set(saves.map { $0.jobId })
                
                print("✅ Loaded \(saves.count) saved jobs")
            }
    }
    
    // MARK: - Check if Job is Saved
    func isSaved(jobId: String) -> Bool {
        return savedJobIds.contains(jobId)
    }
    
    // MARK: - Save Job
    func saveJob(jobId: String, completion: @escaping (Bool, String) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false, "Please login to save jobs")
            return
        }
        
        print("💾 Saving job: \(jobId)")
        
        let save = JobSave(userId: userId, jobId: jobId)
        
        do {
            try db.collection("job_saves").addDocument(from: save) { error in
                if let error = error {
                    print("❌ Error saving job: \(error)")
                    completion(false, "Failed to save job")
                } else {
                    // Increment saved count
                    self.db.collection("jobs").document(jobId).updateData([
                        "savedCount": FieldValue.increment(Int64(1))
                    ])
                    print("✅ Job saved")
                    completion(true, "Job saved")
                }
            }
        } catch {
            print("❌ Error encoding save: \(error)")
            completion(false, "Failed to save job")
        }
    }
    
    // MARK: - Unsave Job
    func unsaveJob(jobId: String, completion: @escaping (Bool, String) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false, "User not logged in")
            return
        }
        
        print("🗑️ Removing saved job: \(jobId)")
        
        db.collection("job_saves")
            .whereField("userId", isEqualTo: userId)
            .whereField("jobId", isEqualTo: jobId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error finding saved job: \(error)")
                    completion(false, "Failed to remove saved job")
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    print("❌ Saved job not found")
                    completion(false, "Saved job not found")
                    return
                }
                
                self?.db.collection("job_saves").document(document.documentID).delete { error in
                    if let error = error {
                        print("❌ Error removing saved job: \(error)")
                        completion(false, "Failed to remove saved job")
                    } else {
                        // Decrement saved count
                        self?.db.collection("jobs").document(jobId).updateData([
                            "savedCount": FieldValue.increment(Int64(-1))
                        ])
                        print("✅ Saved job removed")
                        completion(true, "Saved job removed")
                    }
                }
            }
    }
    
    // MARK: - Toggle Save
    func toggleSave(jobId: String, completion: @escaping (Bool, String) -> Void) {
        if isSaved(jobId: jobId) {
            unsaveJob(jobId: jobId, completion: completion)
        } else {
            saveJob(jobId: jobId, completion: completion)
        }
    }
    
    // MARK: - Get Saved Jobs
    func getSavedJobs() -> [Job] {
        return jobs.filter { job in
            guard let jobId = job.id else { return false }
            return savedJobIds.contains(jobId)
        }
    }
    
    // MARK: - Search & Filter Jobs
    func searchJobs(
        query: String = "",
        category: JobCategory? = nil,
        jobType: JobType? = nil,
        workMode: WorkMode? = nil,
        experienceLevel: ExperienceLevel? = nil,
        salaryMin: Double? = nil,
        salaryMax: Double? = nil,
        location: String = ""
    ) -> [Job] {
        var filtered = jobs
        
        // Search query
        if !query.isEmpty {
            let lowercased = query.lowercased()
            filtered = filtered.filter { job in
                job.title.lowercased().contains(lowercased) ||
                job.company.lowercased().contains(lowercased) ||
                job.description.lowercased().contains(lowercased) ||
                job.skills.contains(where: { $0.lowercased().contains(lowercased) })
            }
        }
        
        // Category filter
        if let category = category {
            filtered = filtered.filter { $0.category == category }
        }
        
        // Job type filter
        if let jobType = jobType {
            filtered = filtered.filter { $0.jobType == jobType }
        }
        
        // Work mode filter
        if let workMode = workMode {
            filtered = filtered.filter { $0.workMode == workMode }
        }
        
        // Experience level filter
        if let experienceLevel = experienceLevel {
            filtered = filtered.filter { $0.experienceLevel == experienceLevel }
        }
        
        // Salary filter
        if let salaryMin = salaryMin {
            filtered = filtered.filter { job in
                guard let jobMin = job.salaryMin else { return false }
                return jobMin >= salaryMin
            }
        }
        
        if let salaryMax = salaryMax {
            filtered = filtered.filter { job in
                guard let jobMax = job.salaryMax else { return false }
                return jobMax <= salaryMax
            }
        }
        
        // Location filter
        if !location.isEmpty {
            let lowercased = location.lowercased()
            filtered = filtered.filter { job in
                job.location.lowercased().contains(lowercased) ||
                job.city.lowercased().contains(lowercased) ||
                job.country.lowercased().contains(lowercased)
            }
        }
        
        return filtered
    }
    
    // MARK: - Get Distance
    func getDistance(to job: Job) -> Double? {
        guard let userLocation = userLocation else { return nil }
        
        let jobLocation = CLLocation(
            latitude: job.latitude,
            longitude: job.longitude
        )
        
        // Convert meters to kilometers
        return userLocation.distance(from: jobLocation) / 1000
    }
}
