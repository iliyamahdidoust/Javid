import SwiftUI
import CoreLocation
import MapKit

struct AddBusinessView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var businessViewModel: BusinessViewModel
    
    // Basic Info
    @State private var name = ""
    @State private var category = "Restaurant"
    @State private var description = ""
    @State private var phone = ""
    
    // Location
    @State private var address = ""
    @State private var city = ""
    @State private var country = "Canada"
    @State private var geocodedCoordinate: CLLocationCoordinate2D?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    // Photos
    @State private var selectedImages: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var editingImageIndex: Int?
    
    // Work Hours
    @State private var workHours: WorkHours = WorkHours()
    @State private var showingWorkHoursEditor = false
    
    // Amenities
    @State private var selectedAmenities: Set<String> = []
    @State private var showingAmenitiesSheet = false
    
    // Social Media
    @State private var website = ""
    @State private var facebook = ""
    @State private var instagram = ""
    @State private var youtube = ""
    
    // Booking
    @State private var bookingEnabled = false
    @State private var showingBookingSettings = false
    
    // UI State
    @State private var currentStep = 0
    @State private var isGeocoding = false
    @State private var isUploading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showPreview = false
    @State private var suggestedAddresses: [String] = []
    @State private var showingSuggestions = false
    @State private var validationErrors: [String: String] = [:]
    
    let categories = [
        "Restaurant", "Cafe", "Shop", "Gym", "Salon", "Hospital",
        "Hotel", "Bar", "Spa", "Cinema", "Park", "Museum"
    ]
    
    let countries = ["Canada", "USA", "UK", "Iran", "Germany", "France", "Italy", "Spain"]
    
    let availableAmenities = [
        "Free WiFi", "Parking", "Card Payment", "Wheelchair Accessible",
        "Outdoor Seating", "Air Conditioned", "Pet Friendly", "Delivery",
        "Takeout", "Reservations", "Live Music", "Bar", "Vegan Options"
    ]
    
    let steps = ["Basic Info", "Location", "Details", "Media", "Review"]
    
    var isStepValid: Bool {
        switch currentStep {
        case 0: return !name.isEmpty && !category.isEmpty && !description.isEmpty && !phone.isEmpty
        case 1: return !address.isEmpty && !city.isEmpty && geocodedCoordinate != nil
        case 2: return true // Optional step
        case 3: return true // Optional step
        case 4: return true // Review step
        default: return false
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Animated Background
                AnimatedGradientBackground()
                
                VStack(spacing: 0) {
                    // Progress Bar
                    progressBar
                    
                    // Step Content
                    TabView(selection: $currentStep) {
                        basicInfoStep.tag(0)
                        locationStep.tag(1)
                        detailsStep.tag(2)
                        mediaStep.tag(3)
                        reviewStep.tag(4)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.3), value: currentStep)
                    
                    // Navigation Buttons
                    navigationButtons
                }
            }
            .navigationTitle("Add Business")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Cancel")
                        }
                        .foregroundColor(.red)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showPreview = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                            Text("Preview")
                        }
                        .foregroundColor(.blue)
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerMultiple(selectedImages: $selectedImages, maxSelection: 10)
            }
            .sheet(isPresented: $showingWorkHoursEditor) {
                WorkHoursEditorSheet(workHours: $workHours)
            }
            .sheet(isPresented: $showingAmenitiesSheet) {
                AmenitiesSelector(
                    availableAmenities: availableAmenities,
                    selectedAmenities: $selectedAmenities
                )
            }
            .sheet(isPresented: $showPreview) {
                BusinessPreviewView(
                    name: name,
                    category: category,
                    description: description,
                    phone: phone,
                    address: address,
                    city: city,
                    country: country,
                    selectedImages: selectedImages,
                    workHours: workHours,
                    amenities: Array(selectedAmenities),
                    coordinate: geocodedCoordinate
                )
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
            .overlay {
                if isUploading {
                    uploadingOverlay
                }
            }
        }
    }
    
    // MARK: - Progress Bar
    private var progressBar: some View {
        VStack(spacing: 12) {
            // Progress Indicators
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 32, height: 32)
                            
                            if index < currentStep {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: .bold))
                            } else {
                                Text("\(index + 1)")
                                    .foregroundColor(index == currentStep ? .white : .gray)
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        
                        Text(steps[index])
                            .font(.caption2)
                            .foregroundColor(index == currentStep ? .blue : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    
                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(index < currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 2)
                            .frame(maxWidth: 30)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    // MARK: - Step 1: Basic Info
    private var basicInfoStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                StepHeader(
                    icon: "info.circle.fill",
                    title: "Basic Information",
                    subtitle: "Tell us about your business"
                )
                
                VStack(spacing: 20) {
                    // Business Name
                    FloatingTextField(
                        title: "Business Name",
                        text: $name,
                        icon: "building.2.fill",
                        placeholder: "Enter business name",
                        error: validationErrors["name"]
                    )
                    .onChange(of: name) { _ in
                        validateField("name")
                    }
                    
                    // Category Selector
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundColor(.blue)
                            Text("Category")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(categories, id: \.self) { cat in
                                    CategoryPill(
                                        title: cat,
                                        icon: iconForCategory(cat),
                                        isSelected: category == cat
                                    ) {
                                        withAnimation(.spring(response: 0.3)) {
                                            category = cat
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "text.alignleft")
                                .foregroundColor(.blue)
                            Text("Description")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        
                        TextEditor(text: $description)
                            .frame(height: 120)
                            .padding(12)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        Text("\(description.count)/500 characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    // Phone
                    FloatingTextField(
                        title: "Phone Number",
                        text: $phone,
                        icon: "phone.fill",
                        placeholder: "+1 (555) 123-4567",
                        keyboardType: .phonePad,
                        error: validationErrors["phone"]
                    )
                    .onChange(of: phone) { _ in
                        validateField("phone")
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Step 2: Location
    private var locationStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                StepHeader(
                    icon: "map.fill",
                    title: "Location",
                    subtitle: "Where is your business located?"
                )
                
                VStack(spacing: 20) {
                    // Address with Autocomplete
                    VStack(alignment: .leading, spacing: 8) {
                        FloatingTextField(
                            title: "Street Address",
                            text: $address,
                            icon: "mappin.and.ellipse",
                            placeholder: "123 Main Street",
                            error: validationErrors["address"]
                        )
                        .onChange(of: address) { newValue in
                            if newValue.count > 3 {
                                searchAddress()
                            } else {
                                showingSuggestions = false
                            }
                        }
                        
                        if showingSuggestions && !suggestedAddresses.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(suggestedAddresses.prefix(3), id: \.self) { suggestion in
                                    Button(action: { selectAddress(suggestion) }) {
                                        HStack {
                                            Image(systemName: "mappin.circle.fill")
                                                .foregroundColor(.blue)
                                            Text(suggestion)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        .padding(12)
                                    }
                                    Divider()
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(radius: 8)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        FloatingTextField(
                            title: "City",
                            text: $city,
                            icon: "building.2.crop.circle",
                            placeholder: "Toronto"
                        )
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "flag.fill")
                                    .foregroundColor(.blue)
                                Text("Country")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Picker("Country", selection: $country) {
                                ForEach(countries, id: \.self) { country in
                                    Text(country).tag(country)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                    
                    // Map Preview
                    if let coordinate = geocodedCoordinate {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Location Verified")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                            }
                            
                            Map(coordinateRegion: $region, annotationItems: [LocationPin(coordinate: coordinate)]) { pin in
                                MapAnnotation(coordinate: pin.coordinate) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 40, height: 40)
                                            .shadow(radius: 4)
                                        
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .frame(height: 200)
                            .cornerRadius(16)
                            .allowsHitTesting(false)
                            
                            Text("Lat: \(String(format: "%.4f", coordinate.latitude)), Lon: \(String(format: "%.4f", coordinate.longitude))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                    
                    if isGeocoding {
                        HStack {
                            ProgressView()
                            Text("Finding location...")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Step 3: Details
    private var detailsStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                StepHeader(
                    icon: "star.circle.fill",
                    title: "Business Details",
                    subtitle: "Add more information (optional)"
                )
                
                VStack(spacing: 20) {
                    // Work Hours
                    DetailCard(
                        icon: "clock.fill",
                        title: "Work Hours",
                        subtitle: workHours.monday.isOpen ? "Configured" : "Not set",
                        color: .orange
                    ) {
                        showingWorkHoursEditor = true
                    }
                    
                    // Amenities
                    DetailCard(
                        icon: "star.circle.fill",
                        title: "Amenities",
                        subtitle: selectedAmenities.isEmpty ? "None selected" : "\(selectedAmenities.count) selected",
                        color: .purple
                    ) {
                        showingAmenitiesSheet = true
                    }
                    
                    // Selected Amenities Preview
                    if !selectedAmenities.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Selected Amenities")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(Array(selectedAmenities), id: \.self) { amenity in
                                    AmenityTag(title: amenity) {
                                        selectedAmenities.remove(amenity)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                    // Booking Settings
                    DetailCard(
                        icon: "calendar.badge.clock",
                        title: "Enable Bookings",
                        subtitle: bookingEnabled ? "Enabled" : "Disabled",
                        color: .green
                    ) {
                        bookingEnabled.toggle()
                    }
                    
                    // Social Media
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "link.circle.fill")
                                .foregroundColor(.blue)
                            Text("Social Media & Website")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        
                        FloatingTextField(
                            title: "Website",
                            text: $website,
                            icon: "globe",
                            placeholder: "https://example.com"
                        )
                        
                        FloatingTextField(
                            title: "Facebook",
                            text: $facebook,
                            icon: "f.square.fill",
                            placeholder: "facebook.com/yourpage"
                        )
                        
                        FloatingTextField(
                            title: "Instagram",
                            text: $instagram,
                            icon: "camera.fill",
                            placeholder: "@yourbusiness"
                        )
                        
                        FloatingTextField(
                            title: "YouTube",
                            text: $youtube,
                            icon: "play.rectangle.fill",
                            placeholder: "youtube.com/@yourchannel"
                        )
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
            }
            .padding()
        }
    }
    // MARK: - Step 4: Media (Continues from File 1)
    
    private var mediaStep: some View {
        ScrollView(.vertical, showsIndicators: true) {  // ✅ Add explicit parameters
            VStack(spacing: 24) {
                StepHeader(
                    icon: "photo.on.rectangle.angled",
                    title: "Photos",
                    subtitle: "Add photos of your business"
                )
            
                
                VStack(spacing: 20) {
                    // Photo Grid
                    if !selectedImages.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 160)
                                        .clipped()
                                        .cornerRadius(16)
                                    
                                    // Remove Button
                                    Button(action: {
                                        withAnimation {
                                            let _ = selectedImages.remove(at: index)
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.red))
                                    }
                                    .padding(8)
                                    
                                    // Primary Badge
                                    if index == 0 {
                                        VStack {
                                            Spacer()
                                            HStack {
                                                Text("Cover Photo")
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.blue)
                                                    .cornerRadius(8)
                                                Spacer()
                                            }
                                            .padding(8)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        // Empty State
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("No photos yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Add photos to showcase your business")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                    
                    // Add Photos Button
                    Button(action: { showingImagePicker = true }) {
                        HStack {
                            Image(systemName: "photo.badge.plus")
                            Text("Add Photos")
                                .fontWeight(.semibold)
                            if !selectedImages.isEmpty {
                                Text("(\(selectedImages.count)/10)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                    }
                    .disabled(selectedImages.count >= 10)
                    
                    if selectedImages.count >= 10 {
                        Text("Maximum 10 photos reached")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Step 5: Review
    private var reviewStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                StepHeader(
                    icon: "checkmark.seal.fill",
                    title: "Review & Submit",
                    subtitle: "Make sure everything looks good"
                )
                
                VStack(spacing: 16) {
                    ReviewSection(title: "Basic Info") {
                        ReviewRow(label: "Name", value: name)
                        ReviewRow(label: "Category", value: category)
                        ReviewRow(label: "Description", value: description)
                        ReviewRow(label: "Phone", value: phone)
                    }
                    
                    ReviewSection(title: "Location") {
                        ReviewRow(label: "Address", value: address)
                        ReviewRow(label: "City", value: city)
                        ReviewRow(label: "Country", value: country)
                        if let coord = geocodedCoordinate {
                            ReviewRow(label: "Coordinates", value: String(format: "%.4f, %.4f", coord.latitude, coord.longitude))
                        }
                    }
                    
                    if workHours.monday.isOpen {
                        ReviewSection(title: "Work Hours") {
                            Text("✓ Configured")
                                .foregroundColor(.green)
                                .font(.subheadline)
                        }
                    }
                    
                    if !selectedAmenities.isEmpty {
                        ReviewSection(title: "Amenities") {
                            FlowLayout(spacing: 8) {
                                ForEach(Array(selectedAmenities), id: \.self) { amenity in
                                    Text(amenity)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    if !selectedImages.isEmpty {
                        ReviewSection(title: "Photos") {
                            Text("\(selectedImages.count) photo\(selectedImages.count == 1 ? "" : "s") added")
                                .foregroundColor(.green)
                                .font(.subheadline)
                        }
                    }
                    
                    // Submit Button
                    Button(action: saveBusiness) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Submit Business")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button(action: { withAnimation { currentStep -= 1 } }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            if currentStep < steps.count - 1 {
                Button(action: { advanceStep() }) {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        isStepValid
                        ? LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(12)
                }
                .disabled(!isStepValid)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 8, y: -4)
    }
    
    // MARK: - Uploading Overlay
    private var uploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Animated Progress Ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isUploading)
                }
                
                VStack(spacing: 8) {
                    Text("Creating Your Business")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Uploading photos and saving details...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemGray6))
                    .shadow(radius: 20)
            )
        }
    }
    
    // MARK: - Helper Functions
    
    func advanceStep() {
        validateCurrentStep()
        if isStepValid {
            withAnimation(.spring(response: 0.3)) {
                currentStep += 1
            }
        }
    }
    
    func validateCurrentStep() {
        validationErrors.removeAll()
        
        switch currentStep {
        case 0:
            if name.isEmpty {
                validationErrors["name"] = "Business name is required"
            }
            if phone.isEmpty {
                validationErrors["phone"] = "Phone number is required"
            } else if !isValidPhone(phone) {
                validationErrors["phone"] = "Invalid phone format"
            }
        case 1:
            if address.isEmpty {
                validationErrors["address"] = "Address is required"
            }
            if geocodedCoordinate == nil && !address.isEmpty {
                // Try to geocode
                geocodeCurrentAddress()
            }
        default:
            break
        }
    }
    
    func validateField(_ field: String) {
        switch field {
        case "name":
            if name.isEmpty {
                validationErrors["name"] = "Required"
            } else {
                validationErrors.removeValue(forKey: "name")
            }
        case "phone":
            if phone.isEmpty {
                validationErrors["phone"] = "Required"
            } else if !isValidPhone(phone) {
                validationErrors["phone"] = "Invalid format"
            } else {
                validationErrors.removeValue(forKey: "phone")
            }
        default:
            break
        }
    }
    
    func isValidPhone(_ phone: String) -> Bool {
        let phoneRegex = "^[+]?[0-9]{10,15}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: ""))
    }
    
    func searchAddress() {
        guard !address.isEmpty, !city.isEmpty else { return }
        isGeocoding = true
        
        let fullAddress = "\(address), \(city), \(country)"
        let geocoder = CLGeocoder()
        
        geocoder.geocodeAddressString(fullAddress) { placemarks, error in
            isGeocoding = false
            
            if let placemarks = placemarks, !placemarks.isEmpty {
                suggestedAddresses = placemarks.prefix(3).compactMap { placemark in
                    var components: [String] = []
                    if let street = placemark.thoroughfare {
                        components.append(street)
                    }
                    if let city = placemark.locality {
                        components.append(city)
                    }
                    return components.isEmpty ? nil : components.joined(separator: ", ")
                }
                showingSuggestions = !suggestedAddresses.isEmpty
            }
        }
    }
    
    func selectAddress(_ suggestion: String) {
        address = suggestion
        showingSuggestions = false
        geocodeCurrentAddress()
    }
    
    func geocodeCurrentAddress() {
        isGeocoding = true
        GeocodingManager.shared.geocodeAddress(
            address: address,
            city: city,
            country: country
        ) { coordinate in
            isGeocoding = false
            
            if let coordinate = coordinate {
                geocodedCoordinate = coordinate
                region.center = coordinate
            }
        }
    }
    
    func iconForCategory(_ category: String) -> String {
        let icons: [String: String] = [
            "Restaurant": "fork.knife",
            "Cafe": "cup.and.saucer.fill",
            "Shop": "bag.fill",
            "Gym": "figure.run",
            "Salon": "scissors",
            "Hospital": "cross.case.fill",
            "Hotel": "bed.double.fill",
            "Bar": "wineglass.fill",
            "Spa": "sparkles",
            "Cinema": "film.fill",
            "Park": "leaf.fill",
            "Museum": "building.columns.fill"
        ]
        return icons[category] ?? "star.fill"
    }
    
    func saveBusiness() {
        guard let coordinate = geocodedCoordinate else {
            alertMessage = "Please set a valid location"
            showingAlert = true
            return
        }
        
        isUploading = true
        
        // Upload images first
        if selectedImages.isEmpty {
            saveBusinessToFirestore(coordinate: coordinate, photoURLs: [])
        } else {
            var uploadedURLs: [String] = []
            let group = DispatchGroup()
            
            for image in selectedImages {
                group.enter()
                businessViewModel.uploadImage(image, for: UUID().uuidString) { url in
                    if let url = url {
                        uploadedURLs.append(url)
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                saveBusinessToFirestore(coordinate: coordinate, photoURLs: uploadedURLs)
            }
        }
    }
    
    func saveBusinessToFirestore(coordinate: CLLocationCoordinate2D, photoURLs: [String]) {
        var socialMediaObj: SocialMedia? = nil
        if !website.isEmpty || !facebook.isEmpty || !instagram.isEmpty || !youtube.isEmpty {
            socialMediaObj = SocialMedia(
                website: website.isEmpty ? nil : website,
                facebook: facebook.isEmpty ? nil : facebook,
                instagram: instagram.isEmpty ? nil : instagram,
                youtube: youtube.isEmpty ? nil : youtube
            )
        }
        
        // ✅ Use this version - calls init explicitly with all required params only
        let business = Business(
            name: name,
            category: category,
            description: description,
            phone: phone,
            address: address,
            city: city,
            country: country,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            ownerId: "",
            photoURLs: photoURLs,
            rating: 0.0,
            reviewCount: 0,
            workHours: workHours.monday.isOpen ? workHours : nil,
            amenities: selectedAmenities.isEmpty ? nil : Array(selectedAmenities),
            socialMedia: socialMediaObj,
            bookingEnabled: bookingEnabled
        )
        
        businessViewModel.addBusiness(business) { success, message in
            isUploading = false
            alertMessage = message
            showingAlert = true
        }
    }
}

    // MARK: - Supporting Components

    struct AnimatedGradientBackground: View {
        @State private var animateGradient = false
        
        var body: some View {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.05),
                    Color.purple.opacity(0.05)
                ],
                startPoint: animateGradient ? .topLeading : .bottomLeading,
                endPoint: animateGradient ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    animateGradient.toggle()
                }
            }
        }
    }

    struct StepHeader: View {
        let icon: String
        let title: String
        let subtitle: String
        
        var body: some View {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    struct FloatingTextField: View {
        let title: String
        @Binding var text: String
        let icon: String
        let placeholder: String
        var keyboardType: UIKeyboardType = .default
        var error: String? = nil
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(error != nil ? Color.red : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                if let error = error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }

    struct CategoryPill: View {
        let title: String
        let icon: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(isSelected ? .white : .blue)
                    
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .primary)
                }
                .frame(width: 80, height: 80)
                .background(
                    isSelected
                        ? LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color(.systemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: isSelected ? Color.blue.opacity(0.3) : Color.clear, radius: 8, y: 4)
            }
        }
    }

    struct DetailCard: View {
        let icon: String
        let title: String
        let subtitle: String
        let color: Color
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: icon)
                            .foregroundColor(color)
                            .font(.title3)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(16)
            }
        }
    }

    struct AmenityTag: View {
        let title: String
        let onRemove: () -> Void
        
        var body: some View {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption)
                
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }

    struct ReviewSection<Content: View>: View {
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
                    .foregroundColor(.primary)
                
                content
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }

    struct ReviewRow: View {
        let label: String
        let value: String
        
        var body: some View {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
        }
    }

    struct LocationPin: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
    }

//    struct FlowLayout: Layout {
//        var spacing: CGFloat = 8
//        
//        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
//            let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
//            return result.size
//        }
//        
//        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
//            let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
//            for (index, subview) in subviews.enumerated() {
//                subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
//            }
//        }
        
//        struct FlowResult {
//            var frames: [CGRect] = []
//            var size: CGSize = .zero
//            
//            init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
//                var currentX: CGFloat = 0
//                var currentY: CGFloat = 0
//                var lineHeight: CGFloat = 0
//                
//                for subview in subviews {
//                    let size = subview.sizeThatFits(.unspecified)
//                    
//                    if currentX + size.width > maxWidth, currentX > 0 {
//                        currentX = 0
//                        currentY += lineHeight + spacing
//                        lineHeight = 0
//                    }
//                    
//                    frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
//                    currentX += size.width + spacing
//                    lineHeight = max(lineHeight, size.height)
//                }
//                
//                self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
//            }
//        }


    // MARK: - Supporting Sheets

    struct WorkHoursEditorSheet: View {
        @Binding var workHours: WorkHours
        @Environment(\.dismiss) var dismiss
        
        var body: some View {
            NavigationView {
                WorkHoursEditorView(business: Business(
                    name: "",
                    category: "",
                    description: "",
                    phone: "",
                    address: "",
                    city: "",
                    country: "",
                    latitude: 0,
                    longitude: 0,
                    ownerId: "",
                    workHours: workHours
                ), businessViewModel: BusinessViewModel())
                .navigationTitle("Work Hours")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

    struct AmenitiesSelector: View {
        let availableAmenities: [String]
        @Binding var selectedAmenities: Set<String>
        @Environment(\.dismiss) var dismiss
        
        var body: some View {
            NavigationView {
                List {
                    ForEach(availableAmenities, id: \.self) { amenity in
                        Button(action: {
                            if selectedAmenities.contains(amenity) {
                                selectedAmenities.remove(amenity)
                            } else {
                                selectedAmenities.insert(amenity)
                            }
                        }) {
                            HStack {
                                Image(systemName: selectedAmenities.contains(amenity) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedAmenities.contains(amenity) ? .blue : .gray)
                                Text(amenity)
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("Select Amenities")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

    struct BusinessPreviewView: View {
        let name, category, description, phone, address, city, country: String
        let selectedImages: [UIImage]
        let workHours: WorkHours
        let amenities: [String]
        let coordinate: CLLocationCoordinate2D?
        @Environment(\.dismiss) var dismiss
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !selectedImages.isEmpty {
                            TabView {
                                ForEach(Array(selectedImages.enumerated()), id: \.offset) { _, image in
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 250)
                                        .clipped()
                                }
                            }
                            .tabViewStyle(.page)
                            .frame(height: 250)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(name)
                                .font(.title)
                                .fontWeight(.bold)
                            Text(category)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                            Text("📞 \(phone)")
                            Text("📍 \(address), \(city), \(country)")
                        }
                        .padding()
                    }
                }
                .navigationTitle("Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }
