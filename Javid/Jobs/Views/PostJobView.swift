import SwiftUI
import FirebaseAuth
import CoreLocation

struct PostJobView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jobViewModel: JobViewModel
    @EnvironmentObject var employerProfileVM: EmployerProfileViewModel
    
    @State private var title = ""
    @State private var description = ""
    @State private var requirements: [String] = [""]
    @State private var responsibilities: [String] = [""]
    @State private var benefits: [String] = [""]
    @State private var skills: [String] = []
    @State private var newSkill = ""
    @State private var jobType: JobType = .fullTime
    @State private var workMode: WorkMode = .onSite
    @State private var experienceLevel: ExperienceLevel = .midLevel
    @State private var category: JobCategory = .technology
    @State private var salaryMin = ""
    @State private var salaryMax = ""
    @State private var salaryCurrency = "$"
    @State private var salaryPeriod: SalaryPeriod = .year
    @State private var location = ""
    @State private var city = ""
    @State private var country = ""
    @State private var applicationDeadline = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days
    @State private var customQuestions: [String] = []
    @State private var newQuestion = ""
    
    @State private var isGeocoding = false
    @State private var geocodedCoordinate: CLLocationCoordinate2D?
    @State private var isPosting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Info
                Section(header: Text("Job Details")) {
                    TextField("Job Title (e.g., Senior iOS Developer)", text: $title)
                    
                    Picker("Category", selection: $category) {
                        ForEach(JobCategory.allCases, id: \.self) { cat in
                            HStack {
                                Image(systemName: cat.icon)
                                Text(cat.rawValue)
                            }
                            .tag(cat)
                        }
                    }
                    
                    Picker("Job Type", selection: $jobType) {
                        ForEach(JobType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    Picker("Work Mode", selection: $workMode) {
                        ForEach(WorkMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    
                    Picker("Experience Level", selection: $experienceLevel) {
                        ForEach(ExperienceLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                }
                
                // Description
                Section(header: Text("Description")) {
                    TextEditor(text: $description)
                        .frame(height: 120)
                }
                
                // Requirements
                Section(header: Text("Requirements")) {
                    ForEach(requirements.indices, id: \.self) { index in
                        HStack {
                            TextField("Requirement", text: $requirements[index])
                            if requirements.count > 1 {
                                Button(action: { requirements.remove(at: index) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    Button(action: { requirements.append("") }) {
                        Label("Add Requirement", systemImage: "plus.circle")
                    }
                }
                
                // Responsibilities
                Section(header: Text("Responsibilities")) {
                    ForEach(responsibilities.indices, id: \.self) { index in
                        HStack {
                            TextField("Responsibility", text: $responsibilities[index])
                            if responsibilities.count > 1 {
                                Button(action: { responsibilities.remove(at: index) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    Button(action: { responsibilities.append("") }) {
                        Label("Add Responsibility", systemImage: "plus.circle")
                    }
                }
                
                // Benefits
                Section(header: Text("Benefits (Optional)")) {
                    ForEach(benefits.indices, id: \.self) { index in
                        HStack {
                            TextField("Benefit", text: $benefits[index])
                            Button(action: { benefits.remove(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    Button(action: { benefits.append("") }) {
                        Label("Add Benefit", systemImage: "plus.circle")
                    }
                }
                
                // Skills
                Section(header: Text("Required Skills")) {
                    ForEach(skills, id: \.self) { skill in
                        HStack {
                            Text(skill)
                            Spacer()
                            Button(action: { skills.removeAll { $0 == skill } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    HStack {
                        TextField("Add skill", text: $newSkill)
                        Button("Add") {
                            if !newSkill.isEmpty {
                                skills.append(newSkill)
                                newSkill = ""
                            }
                        }
                    }
                }
                
                // Salary
                Section(header: Text("Salary Range (Optional)")) {
                    HStack {
                        TextField("Min", text: $salaryMin)
                            .keyboardType(.numberPad)
                        Text("-")
                        TextField("Max", text: $salaryMax)
                            .keyboardType(.numberPad)
                    }
                    
                    Picker("Period", selection: $salaryPeriod) {
                        ForEach(SalaryPeriod.allCases, id: \.self) { period in
                            Text("per \(period.rawValue)").tag(period)
                        }
                    }
                }
                
                // Location
                Section(header: Text("Location")) {
                    TextField("Address/Street", text: $location)
                    TextField("City", text: $city)
                    TextField("Country", text: $country)
                    
                    if let coordinate = geocodedCoordinate {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Location verified")
                                .font(.caption)
                        }
                    }
                    
                    Button(action: geocodeLocation) {
                        if isGeocoding {
                            HStack {
                                ProgressView()
                                Text("Verifying location...")
                            }
                        } else {
                            Label("Verify Location", systemImage: "location.fill")
                        }
                    }
                    .disabled(city.isEmpty || country.isEmpty)
                }
                
                // Deadline
                Section(header: Text("Application Deadline")) {
                    DatePicker("Deadline", selection: $applicationDeadline, in: Date()..., displayedComponents: .date)
                }
                
                // Custom Questions
                Section(header: Text("Custom Questions (Optional)")) {
                    ForEach(customQuestions.indices, id: \.self) { index in
                        HStack {
                            TextField("Question", text: $customQuestions[index])
                            Button(action: { customQuestions.remove(at: index) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    HStack {
                        TextField("Add custom question", text: $newQuestion)
                        Button("Add") {
                            if !newQuestion.isEmpty {
                                customQuestions.append(newQuestion)
                                newQuestion = ""
                            }
                        }
                    }
                }
                
                // Post Button
                Section {
                    Button(action: postJob) {
                        if isPosting {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("Post Job")
                                    .bold()
                                Spacer()
                            }
                        }
                    }
                    .disabled(!isValid || isPosting)
                }
            }
            .navigationTitle("Post a Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(isPosting)
                }
            }
            .alert("Message", isPresented: $showingAlert) {
                Button("OK") {
                    if alertMessage.contains("successfully") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    var isValid: Bool {
        !title.isEmpty && !description.isEmpty &&
        !requirements.filter { !$0.isEmpty }.isEmpty &&
        !responsibilities.filter { !$0.isEmpty }.isEmpty &&
        !city.isEmpty && !country.isEmpty &&
        geocodedCoordinate != nil
    }
    
    func geocodeLocation() {
        isGeocoding = true
        let fullAddress = "\(location), \(city), \(country)"
        
        GeocodingManager.shared.geocodeAddress(address: fullAddress, city: city, country: country) { coordinate in
            isGeocoding = false
            geocodedCoordinate = coordinate
        }
    }
    
    func postJob() {
        guard let coordinate = geocodedCoordinate,
              let profile = employerProfileVM.employerProfile,
              let userId = Auth.auth().currentUser?.uid,
              let userName = Auth.auth().currentUser?.displayName,
              let userEmail = Auth.auth().currentUser?.email else {
            alertMessage = "Missing required information"
            showingAlert = true
            return
        }
        
        isPosting = true
        
        let job = Job(
            title: title,
            company: profile.companyName,
            companyLogo: profile.logoURL,
            description: description,
            requirements: requirements.filter { !$0.isEmpty },
            responsibilities: responsibilities.filter { !$0.isEmpty },
            benefits: benefits.filter { !$0.isEmpty },
            jobType: jobType,
            workMode: workMode,
            experienceLevel: experienceLevel,
            salaryMin: Double(salaryMin),
            salaryMax: Double(salaryMax),
            salaryCurrency: salaryCurrency,
            salaryPeriod: salaryPeriod,
            category: category,
            skills: skills,
            location: location,
            city: city,
            country: country,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            employerId: userId,
            employerName: userName,
            employerEmail: userEmail,
            employerVerified: employerProfileVM.employerProfile?.isVerified ?? false,
            applicationDeadline: applicationDeadline,
            questions: customQuestions
        )
        
        jobViewModel.addJob(job) { success, message in
            isPosting = false
            alertMessage = message
            showingAlert = true
            
            if success {
            }
        }
    }
}
