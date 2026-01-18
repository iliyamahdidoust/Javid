import SwiftUI

struct EditJobSeekerProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var profileVM: JobSeekerProfileViewModel
    
    @State private var fullName = ""
    @State private var headline = ""
    @State private var summary = ""
    @State private var phone = ""
    @State private var city = ""
    @State private var country = ""
    @State private var skills: [String] = []
    @State private var newSkill = ""
    @State private var isSaving = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Full Name", text: $fullName)
                    TextField("Professional Headline", text: $headline)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section(header: Text("About")) {
                    TextEditor(text: $summary)
                        .frame(height: 100)
                }
                
                Section(header: Text("Location")) {
                    TextField("City", text: $city)
                    TextField("Country", text: $country)
                }
                
                Section(header: Text("Skills")) {
                    ForEach(skills, id: \.self) { skill in
                        HStack {
                            Text(skill)
                            Spacer()
                            Button(action: {
                                skills.removeAll { $0 == skill }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("Add skill", text: $newSkill)
                        Button("Add") {
                            if !newSkill.isEmpty && !skills.contains(newSkill) {
                                skills.append(newSkill)
                                newSkill = ""
                            }
                        }
                        .disabled(newSkill.isEmpty)
                    }
                }
                
                Section {
                    Button(action: saveProfile) {
                        if isSaving {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("Save Changes")
                                    .bold()
                                Spacer()
                            }
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
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
            .onAppear {
                loadData()
            }
        }
    }
    
    func loadData() {
        guard let profile = profileVM.profile else { return }
        fullName = profile.fullName
        headline = profile.headline
        summary = profile.summary
        phone = profile.phone
        city = profile.city
        country = profile.country
        skills = profile.skills
    }
    
    func saveProfile() {
        guard var profile = profileVM.profile else { return }
        
        profile.fullName = fullName
        profile.headline = headline
        profile.summary = summary
        profile.phone = phone
        profile.city = city
        profile.country = country
        profile.skills = skills
        
        isSaving = true
        
        profileVM.updateProfile(profile) { success, message in
            isSaving = false
            alertMessage = message
            showingAlert = true
        }
    }
}
