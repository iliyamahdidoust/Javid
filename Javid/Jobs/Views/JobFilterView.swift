import SwiftUI

struct JobFilterView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedCategories: Set<JobCategory>
    @Binding var selectedTypes: Set<JobType>
    @Binding var selectedLocation: String
    @Binding var selectedRemoteOption: RemoteOption?
    @Binding var minSalary: Double
    @Binding var maxSalary: Double
    @Binding var selectedExperienceLevel: ExperienceLevel?
    @Binding var postedWithin: PostedWithin?
    
    @State private var localCategories: Set<JobCategory>
    @State private var localTypes: Set<JobType>
    @State private var localLocation: String
    @State private var localRemoteOption: RemoteOption?
    @State private var localMinSalary: Double
    @State private var localMaxSalary: Double
    @State private var localExperienceLevel: ExperienceLevel?
    @State private var localPostedWithin: PostedWithin?
    
    init(
        selectedCategories: Binding<Set<JobCategory>>,
        selectedTypes: Binding<Set<JobType>>,
        selectedLocation: Binding<String>,
        selectedRemoteOption: Binding<RemoteOption?>,
        minSalary: Binding<Double>,
        maxSalary: Binding<Double>,
        selectedExperienceLevel: Binding<ExperienceLevel?>,
        postedWithin: Binding<PostedWithin?>
    ) {
        self._selectedCategories = selectedCategories
        self._selectedTypes = selectedTypes
        self._selectedLocation = selectedLocation
        self._selectedRemoteOption = selectedRemoteOption
        self._minSalary = minSalary
        self._maxSalary = maxSalary
        self._selectedExperienceLevel = selectedExperienceLevel
        self._postedWithin = postedWithin
        
        _localCategories = State(initialValue: selectedCategories.wrappedValue)
        _localTypes = State(initialValue: selectedTypes.wrappedValue)
        _localLocation = State(initialValue: selectedLocation.wrappedValue)
        _localRemoteOption = State(initialValue: selectedRemoteOption.wrappedValue)
        _localMinSalary = State(initialValue: minSalary.wrappedValue)
        _localMaxSalary = State(initialValue: maxSalary.wrappedValue)
        _localExperienceLevel = State(initialValue: selectedExperienceLevel.wrappedValue)
        _localPostedWithin = State(initialValue: postedWithin.wrappedValue)
    }
    
    var activeFilterCount: Int {
        var count = 0
        if !localCategories.isEmpty { count += 1 }
        if !localTypes.isEmpty { count += 1 }
        if !localLocation.isEmpty { count += 1 }
        if localRemoteOption != nil { count += 1 }
        if localMinSalary > 0 || localMaxSalary < 500000 { count += 1 }
        if localExperienceLevel != nil { count += 1 }
        if localPostedWithin != nil { count += 1 }
        return count
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Posted Within
                    FilterSection(title: "Posted") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(PostedWithin.allCases, id: \.self) { option in
                                    FilterChipButton(
                                        title: option.rawValue,
                                        isSelected: localPostedWithin == option,
                                        action: {
                                            localPostedWithin = localPostedWithin == option ? nil : option
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Job Categories
                    FilterSection(title: "Categories") {
                        FlowLayout(spacing: 8) {
                            ForEach(JobCategory.allCases, id: \.self) { category in
                                FilterChipButton(
                                    title: category.rawValue,
                                    isSelected: localCategories.contains(category),
                                    action: {
                                        if localCategories.contains(category) {
                                            localCategories.remove(category)
                                        } else {
                                            localCategories.insert(category)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Job Types
                    FilterSection(title: "Job Type") {
                        FlowLayout(spacing: 8) {
                            ForEach(JobType.allCases, id: \.self) { type in
                                FilterChipButton(
                                    title: type.rawValue,
                                    isSelected: localTypes.contains(type),
                                    action: {
                                        if localTypes.contains(type) {
                                            localTypes.remove(type)
                                        } else {
                                            localTypes.insert(type)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Remote Options
                    FilterSection(title: "Work Location") {
                        FlowLayout(spacing: 8) {
                            ForEach(RemoteOption.allCases, id: \.self) { option in
                                FilterChipButton(
                                    title: option.rawValue,
                                    isSelected: localRemoteOption == option,
                                    action: {
                                        localRemoteOption = localRemoteOption == option ? nil : option
                                    }
                                )
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Experience Level
                    FilterSection(title: "Experience Level") {
                        FlowLayout(spacing: 8) {
                            ForEach(ExperienceLevel.allCases, id: \.self) { level in
                                FilterChipButton(
                                    title: level.rawValue,
                                    isSelected: localExperienceLevel == level,
                                    action: {
                                        localExperienceLevel = localExperienceLevel == level ? nil : level
                                    }
                                )
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Location
                    FilterSection(title: "Location") {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.blue)
                            
                            TextField("Enter city or region", text: $localLocation)
                                .textFieldStyle(PlainTextFieldStyle())
                            
                            if !localLocation.isEmpty {
                                Button(action: { localLocation = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                    
                    Divider()
                    
                    // Salary Range
                    FilterSection(title: "Salary Range") {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("$\(Int(localMinSalary).formatted())")
                                    .font(.headline)
                                Spacer()
                                Text("$\(Int(localMaxSalary).formatted())")
                                    .font(.headline)
                            }
                            
                            VStack(spacing: 8) {
                                Text("Minimum: $\(Int(localMinSalary).formatted())")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Slider(value: $localMinSalary, in: 0...500000, step: 5000)
                                    .tint(.blue)
                            }
                            
                            VStack(spacing: 8) {
                                Text("Maximum: $\(Int(localMaxSalary).formatted())")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Slider(value: $localMaxSalary, in: 0...500000, step: 5000)
                                    .tint(.blue)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        resetFilters()
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyFilters()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func resetFilters() {
        localCategories = []
        localTypes = []
        localLocation = ""
        localRemoteOption = nil
        localMinSalary = 0
        localMaxSalary = 500000
        localExperienceLevel = nil
        localPostedWithin = nil
    }
    
    private func applyFilters() {
        selectedCategories = localCategories
        selectedTypes = localTypes
        selectedLocation = localLocation
        selectedRemoteOption = localRemoteOption
        minSalary = localMinSalary
        maxSalary = localMaxSalary
        selectedExperienceLevel = localExperienceLevel
        postedWithin = localPostedWithin
        dismiss()
    }
}

struct FilterSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            content
        }
    }
}

struct FilterChipButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

// Flow Layout for wrapping chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

enum PostedWithin: String, CaseIterable {
    case anyTime = "Any Time"
    case last24Hours = "Last 24 Hours"
    case last7Days = "Last 7 Days"
    case last14Days = "Last 14 Days"
    case last30Days = "Last 30 Days"
    
    var dateRange: Date {
        let calendar = Calendar.current
        switch self {
        case .anyTime:
            return Date.distantPast
        case .last24Hours:
            return calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .last14Days:
            return calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        case .last30Days:
            return calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        }
    }
}
