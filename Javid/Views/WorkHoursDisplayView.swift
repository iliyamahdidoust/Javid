import SwiftUI

struct WorkHoursDisplayView: View {
    let workHours: WorkHours
    
    var daysData: [(String, DayHours)] {
        [
            ("Monday", workHours.monday),
            ("Tuesday", workHours.tuesday),
            ("Wednesday", workHours.wednesday),
            ("Thursday", workHours.thursday),
            ("Friday", workHours.friday),
            ("Saturday", workHours.saturday),
            ("Sunday", workHours.sunday)
        ]
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(daysData.enumerated()), id: \.offset) { index, item in
                let (day, dayHours) = item
                
                HStack {
                    Text(day)
                        .font(.subheadline)
                        .frame(width: 100, alignment: .leading)
                    
                    Spacer()
                    
                    if dayHours.isOpen {
                        Text("\(dayHours.openTime) - \(dayHours.closeTime)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    } else {
                        Text("Closed")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
                
                if index < daysData.count - 1 {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
