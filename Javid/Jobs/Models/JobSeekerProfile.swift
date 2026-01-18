import Foundation
import FirebaseFirestore

// MARK: - Job Seeker Profile
struct JobSeekerProfile: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var fullName: String
    var email: String
    var phone: String
    var profilePhotoURL: String?
    var headline: String // e.g., "Senior iOS Developer"
    var summary: String
    var location: String
    var city: String
    var country: String
    var resumeURL: String?
    var portfolioURL: String?
    var linkedInURL: String?
    var githubURL: String?
    var website: String?
    var skills: [String]
    var languages: [Language]
    var experience: [WorkExperience]
    var education: [Education]
    var certifications: [Certification]
    var preferences: JobPreferences
    var createdAt: Date
    var updatedAt: Date
    var isActive: Bool = true
    var profileCompleteness: Int = 0 // 0-100%
    
    init(
        userId: String,
        fullName: String,
        email: String,
        phone: String = "",
        headline: String = "",
        summary: String = "",
        location: String = "",
        city: String = "",
        country: String = ""
    ) {
        self.userId = userId
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.headline = headline
        self.summary = summary
        self.location = location
        self.city = city
        self.country = country
        self.skills = []
        self.languages = []
        self.experience = []
        self.education = []
        self.certifications = []
        self.preferences = JobPreferences()
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    mutating func calculateCompleteness() {
        var score = 0
        
        // Basic info (30 points)
        if !fullName.isEmpty { score += 5 }
        if !email.isEmpty { score += 5 }
        if !phone.isEmpty { score += 5 }
        if !headline.isEmpty { score += 5 }
        if !summary.isEmpty { score += 10 }
        
        // Documents (20 points)
        if resumeURL != nil { score += 15 }
        if portfolioURL != nil { score += 5 }
        
        // Skills & Languages (20 points)
        if !skills.isEmpty { score += 10 }
        if !languages.isEmpty { score += 10 }
        
        // Experience & Education (20 points)
        if !experience.isEmpty { score += 10 }
        if !education.isEmpty { score += 10 }
        
        // Additional (10 points)
        if !certifications.isEmpty { score += 5 }
        if profilePhotoURL != nil { score += 5 }
        
        profileCompleteness = score
    }
}

// MARK: - Language
struct Language: Codable, Identifiable {
    var id = UUID().uuidString
    var name: String
    var proficiency: LanguageProficiency
}

enum LanguageProficiency: String, Codable, CaseIterable {
    case elementary = "Elementary"
    case limited = "Limited Working"
    case professional = "Professional"
    case fluent = "Fluent"
    case native = "Native"
}

// MARK: - Work Experience
struct WorkExperience: Codable, Identifiable {
    var id = UUID().uuidString
    var title: String
    var company: String
    var location: String
    var startDate: Date
    var endDate: Date?
    var isCurrent: Bool
    var description: String
    var achievements: [String]
}

// MARK: - Education
struct Education: Codable, Identifiable {
    var id = UUID().uuidString
    var degree: String // e.g., "Bachelor of Science"
    var fieldOfStudy: String // e.g., "Computer Science"
    var school: String
    var location: String
    var startDate: Date
    var endDate: Date?
    var isCurrent: Bool
    var gpa: String?
    var description: String
}

// MARK: - Certification
struct Certification: Codable, Identifiable {
    var id = UUID().uuidString
    var name: String
    var issuingOrganization: String
    var issueDate: Date
    var expirationDate: Date?
    var credentialID: String?
    var credentialURL: String?
}

// MARK: - Job Preferences
struct JobPreferences: Codable {
    var jobTypes: [JobType] = []
    var workModes: [WorkMode] = []
    var categories: [JobCategory] = []
    var desiredSalaryMin: Double?
    var desiredSalaryMax: Double?
    var salaryCurrency: String = "$"
    var willingToRelocate: Bool = false
    var availableStartDate: Date?
}
