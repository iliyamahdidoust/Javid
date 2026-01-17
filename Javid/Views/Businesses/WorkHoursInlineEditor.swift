import SwiftUI

struct WorkHoursInlineEditor: View {
    @Binding var workHours: WorkHours
    
    let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    
    var body: some View {
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
                                .frame(width: 80)
                        }
                        
                        HStack {
                            Text("Closes at")
                            Spacer()
                            TextField("17:00", text: binding(for: day).closeTime)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numbersAndPunctuation)
                                .frame(width: 80)
                        }
                    }
                }
            }
        }
        .navigationTitle("Work Hours")
        .navigationBarTitleDisplayMode(.inline)
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
}
