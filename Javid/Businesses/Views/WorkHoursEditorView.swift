import SwiftUI

struct WorkHoursEditorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var businessViewModel: BusinessViewModel
    
    let business: Business
    @State private var workHours: WorkHours
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSaving = false
    
    let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    
    init(business: Business, businessViewModel: BusinessViewModel) {
        self.business = business
        self.businessViewModel = businessViewModel
        _workHours = State(initialValue: business.workHours ?? WorkHours())
    }
    
    var body: some View {
        NavigationView {
            Form {
                ForEach(days, id: \.self) { day in
                    Section(header: Text(day)) {
                        Toggle("Open", isOn: binding(for: day).isOpen)
                        
                        if binding(for: day).isOpen.wrappedValue {
                            HStack {
                                Text("Opens at")
                                Spacer()
                                TextField("09:00", text: binding(for: day).openTime)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.numbersAndPunctuation)
                            }
                            
                            HStack {
                                Text("Closes at")
                                Spacer()
                                TextField("17:00", text: binding(for: day).closeTime)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.numbersAndPunctuation)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: saveWorkHours) {
                        if isSaving {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("Save Work Hours")
                                    .bold()
                                Spacer()
                            }
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .navigationTitle("Work Hours")
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
    
    func binding(for day: String) -> Binding<DayHours> {
        switch day {
        case "Monday": return $workHours.monday
        case "Tuesday": return $workHours.tuesday
        case "Wednesday": return $workHours.wednesday
        case "Thursday": return $workHours.thursday
        case "Friday": return $workHours.friday
        case "Saturday": return $workHours.saturday
        case "Sunday": return $workHours.sunday
        default: return $workHours.monday
        }
    }
    
    func saveWorkHours() {
        isSaving = true
        
        var updatedBusiness = business
        updatedBusiness.workHours = workHours
        
        businessViewModel.updateBusiness(updatedBusiness) { success, message in
            isSaving = false
            alertMessage = message
            showingAlert = true
        }
    }
}
