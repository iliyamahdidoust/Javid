import Foundation
import FirebaseFirestore
import CoreLocation

// MARK: - Job Model
struct Job: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var company: String
    var companyLogo: String?
    var description: String
    var requirements: [String]
    var responsibilities: [String]
    var benefits: [String]
    var jobType: JobType
    var workMode: WorkMode
    var experienceLevel: ExperienceLevel
    var salaryMin: Double?
    var salaryMax: Double?
    var salaryCurrency: String
    var salaryPeriod: SalaryPeriod
    var category: JobCategory
    var skills: [String]
    var location: String
    var city: String
    var country: String
    var latitude: Double
    var longitude: Double
    var employerId: String
    var employerName: String
    var employerEmail: String
    var employerVerified: Bool
    var applicationDeadline: Date?
    var createdAt: Date
    var updatedAt: Date
    var viewCount: Int = 0
    var applicationCount: Int = 0
    var savedCount: Int = 0
    var isActive: Bool = true
    var questions: [String] = [] // Custom questions for applicants
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var salaryRange: String {
        guard let min = salaryMin, let max = salaryMax else {
            return "Not specified"
        }
        return "\(salaryCurrency)\(formatNumber(min)) - \(salaryCurrency)\(formatNumber(max)) / \(salaryPeriod.rawValue)"
    }
    
    private func formatNumber(_ num: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: num)) ?? "\(Int(num))"
    }
    
    init(
        id: String = UUID().uuidString,
        title: String,
        company: String,
        companyLogo: String? = nil,
        description: String,
        requirements: [String],
        responsibilities: [String],
        benefits: [String],
        jobType: JobType,
        workMode: WorkMode,
        experienceLevel: ExperienceLevel,
        salaryMin: Double?,
        salaryMax: Double?,
        salaryCurrency: String = "$",
        salaryPeriod: SalaryPeriod,
        category: JobCategory,
        skills: [String],
        location: String,
        city: String,
        country: String,
        latitude: Double,
        longitude: Double,
        employerId: String,
        employerName: String,
        employerEmail: String,
        employerVerified: Bool = false,
        applicationDeadline: Date? = nil,
        questions: [String] = []
    ) {
        self.id = id
        self.title = title
        self.company = company
        self.companyLogo = companyLogo
        self.description = description
        self.requirements = requirements
        self.responsibilities = responsibilities
        self.benefits = benefits
        self.jobType = jobType
        self.workMode = workMode
        self.experienceLevel = experienceLevel
        self.salaryMin = salaryMin
        self.salaryMax = salaryMax
        self.salaryCurrency = salaryCurrency
        self.salaryPeriod = salaryPeriod
        self.category = category
        self.skills = skills
        self.location = location
        self.city = city
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.employerId = employerId
        self.employerName = employerName
        self.employerEmail = employerEmail
        self.employerVerified = employerVerified
        self.applicationDeadline = applicationDeadline
        self.createdAt = Date()
        self.updatedAt = Date()
        self.questions = questions
    }
}

// MARK: - Job Type
enum JobType: String, Codable, CaseIterable {
    case fullTime = "Full-time"
    case partTime = "Part-time"
    case contract = "Contract"
    case temporary = "Temporary"
    case internship = "Internship"
    case volunteer = "Volunteer"
    
    var icon: String {
        switch self {
        case .fullTime: return "briefcase.fill"
        case .partTime: return "briefcase"
        case .contract: return "doc.text.fill"
        case .temporary: return "clock.fill"
        case .internship: return "graduationcap.fill"
        case .volunteer: return "heart.fill"
        }
    }
}

// MARK: - Work Mode
enum WorkMode: String, Codable, CaseIterable {
    case onSite = "On-site"
    case remote = "Remote"
    case hybrid = "Hybrid"
    
    var icon: String {
        switch self {
        case .onSite: return "building.2.fill"
        case .remote: return "house.fill"
        case .hybrid: return "arrow.left.arrow.right"
        }
    }
}

// MARK: - Experience Level
enum ExperienceLevel: String, Codable, CaseIterable {
    case entryLevel = "Entry Level"
    case midLevel = "Mid Level"
    case seniorLevel = "Senior Level"
    case executive = "Executive"
    case internship = "Internship"
    
    var yearsRange: String {
        switch self {
        case .entryLevel: return "0-2 years"
        case .midLevel: return "2-5 years"
        case .seniorLevel: return "5-10 years"
        case .executive: return "10+ years"
        case .internship: return "No experience required"
        }
    }
}

// MARK: - Salary Period
enum SalaryPeriod: String, Codable, CaseIterable {
    case hour = "hour"
    case day = "day"
    case month = "month"
    case year = "year"
}

// MARK: - Job Category
enum JobCategory: String, Codable, CaseIterable {
    case technology = "Technology"
    case healthcare = "Healthcare"
    case finance = "Finance"
    case education = "Education"
    case marketing = "Marketing"
    case sales = "Sales"
    case design = "Design"
    case engineering = "Engineering"
    case customerService = "Customer Service"
    case administration = "Administration"
    case legal = "Legal"
    case humanResources = "Human Resources"
    case operations = "Operations"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .technology: return "desktopcomputer"
        case .healthcare: return "cross.case.fill"
        case .finance: return "dollarsign.circle.fill"
        case .education: return "book.fill"
        case .marketing: return "megaphone.fill"
        case .sales: return "cart.fill"
        case .design: return "paintbrush.fill"
        case .engineering: return "gearshape.fill"
        case .customerService: return "person.2.fill"
        case .administration: return "folder.fill"
        case .legal: return "scale.3d"
        case .humanResources: return "person.3.fill"
        case .operations: return "chart.bar.fill"
        case .other: return "square.grid.2x2"
        }
    }
    
    var color: String {
        switch self {
        case .technology: return "3B82F6"
        case .healthcare: return "EF4444"
        case .finance: return "10B981"
        case .education: return "F59E0B"
        case .marketing: return "EC4899"
        case .sales: return "8B5CF6"
        case .design: return "F97316"
        case .engineering: return "06B6D4"
        case .customerService: return "84CC16"
        case .administration: return "6366F1"
        case .legal: return "14B8A6"
        case .humanResources: return "F43F5E"
        case .operations: return "0EA5E9"
        case .other: return "6B7280"
        }
    }
}
