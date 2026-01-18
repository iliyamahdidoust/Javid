import SwiftUI
import MapKit

struct EditBusinessView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var businessViewModel: BusinessViewModel
    
    var business: Business
    
    @State private var name: String
    @State private var category: String
    @State private var description: String
    @State private var phone: String
    @State private var address: String
    @State private var city: String
    @State private var country: String
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSaving = false
    
    let categories = ["Restaurant", "Store", "Services", "Doctor", "Lawyer", "Salon"]
    
    init(business: Business, businessViewModel: BusinessViewModel) {
        self.business = business
        self.businessViewModel = businessViewModel
        
        _name = State(initialValue: business.name)
        _category = State(initialValue: business.category)
        _description = State(initialValue: business.description)
        _phone = State(initialValue: business.phone)
        _address = State(initialValue: business.address)
        _city = State(initialValue: business.city)
        _country = State(initialValue: business.country)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Business Name", text: $name)
                    
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section(header: Text("Description")) {
                    TextEditor(text: $description)
                        .frame(height: 100)
                }
                
                Section(header: Text("Location")) {
                    TextField("Address", text: $address)
                    TextField("City", text: $city)
                    TextField("Country", text: $country)
                }
                
                Section {
                    Button(action: updateBusiness) {
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
            .navigationTitle("Edit Business")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Message", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {
                    if alertMessage.contains("successfully") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    func updateBusiness() {
        // Validation
        guard !name.isEmpty else {
            alertMessage = "❌ Please enter business name"
            showingAlert = true
            return
        }
        
        guard !phone.isEmpty else {
            alertMessage = "❌ Please enter phone number"
            showingAlert = true
            return
        }
        
        guard !address.isEmpty else {
            alertMessage = "❌ Please enter address"
            showingAlert = true
            return
        }
        
        guard !city.isEmpty else {
            alertMessage = "❌ Please enter city"
            showingAlert = true
            return
        }
        
        guard !country.isEmpty else {
            alertMessage = "❌ Please enter country"
            showingAlert = true
            return
        }
        
        isSaving = true
        
        // Create updated business
        var updatedBusiness = business
        updatedBusiness.name = name
        updatedBusiness.category = category
        updatedBusiness.description = description
        updatedBusiness.phone = phone
        updatedBusiness.address = address
        updatedBusiness.city = city
        updatedBusiness.country = country
        
        businessViewModel.updateBusiness(updatedBusiness) { success, message in
            isSaving = false
            alertMessage = message
            showingAlert = true
        }
    }
}
