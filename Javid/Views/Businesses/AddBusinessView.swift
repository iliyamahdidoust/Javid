import SwiftUI
import CoreLocation

struct AddBusinessView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var businessViewModel: BusinessViewModel
    
    @State private var name = ""
    @State private var category = "Restaurant"
    @State private var description = ""
    @State private var address = ""
    @State private var city = ""
    @State private var country = "Iran"
    @State private var phone = ""
    @State private var selectedImages: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var isUploading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // Geocoding states
    @State private var isGeocoding = false
    @State private var suggestedAddresses: [String] = []
    @State private var showingSuggestions = false
    @State private var geocodedCoordinate: CLLocationCoordinate2D?
    
    let categories = ["Restaurant", "Store", "Services", "Doctor", "Lawyer", "Salon"]
    let countries = ["Iran", "USA", "Canada", "UK", "Germany", "France"]
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Info Section
                Section(header: Text("Basic Information")) {
                    TextField("Business Name", text: $name)
                    
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // Location Section with Autocomplete
                Section(header: Text("Location")) {
                    // Address field with autocomplete
                    VStack(alignment: .leading, spacing: 0) {
                        addressInputField
                        
                        // Address suggestions dropdown
                        if showingSuggestions && !suggestedAddresses.isEmpty {
                            addressSuggestionsList
                        }
                    }
                    
                    TextField("City", text: $city)
                    
                    Picker("Country", selection: $country) {
                        ForEach(countries, id: \.self) { country in
                            Text(country).tag(country)
                        }
                    }
                    
                    // Show geocoded location status
                    if let coordinate = geocodedCoordinate {
                        locationVerificationView(coordinate: coordinate)
                    }
                }
                
                // Contact Section
                Section(header: Text("Contact Information")) {
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                // Photos Section
                Section(header: Text("Photos (Optional)")) {
                    if !selectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Button(action: {
                                            selectedImages.remove(at: index)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Color.white.clipShape(Circle()))
                                        }
                                        .offset(x: 5, y: -5)
                                    }
                                }
                            }
                        }
                    }
                    
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        Label("Add Photos", systemImage: "photo.on.rectangle.angled")
                    }
                    .disabled(selectedImages.count >= 5)
                }
            }
            .navigationTitle("Add Business")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBusiness()
                    }
                    .disabled(isUploading || name.isEmpty || address.isEmpty || city.isEmpty || phone.isEmpty)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerMultiple(selectedImages: $selectedImages, maxSelection: 5)
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
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Uploading business...")
                                .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    // Address input field
    private var addressInputField: some View {
        HStack {
            TextField("Address (e.g., Valiasr St)", text: $address)
                .onChange(of: address) { newValue in
                    if newValue.count > 3 {
                        searchAddress()
                    } else {
                        showingSuggestions = false
                    }
                }
            
            if isGeocoding {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }
    
    // Address suggestions list
    private var addressSuggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestedAddresses, id: \.self) { suggestion in
                Button(action: {
                    selectAddress(suggestion)
                }) {
                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.top, 4)
    }
    
    // Location verification view
    private func locationVerificationView(coordinate: CLLocationCoordinate2D) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Location verified")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude))
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Functions
    
    // Search for address suggestions
    func searchAddress() {
        guard !address.isEmpty, !city.isEmpty else { return }
        
        isGeocoding = true
        
        // Create full address for geocoding
        let fullAddress = "\(address), \(city), \(country)"
        
        // Use CLGeocoder for suggestions
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
                    if let country = placemark.country {
                        components.append(country)
                    }
                    return components.isEmpty ? nil : components.joined(separator: ", ")
                }
                showingSuggestions = !suggestedAddresses.isEmpty
            }
        }
    }
    
    // Select an address from suggestions
    func selectAddress(_ suggestion: String) {
        showingSuggestions = false
        
        // Geocode the selected address to get coordinates
        isGeocoding = true
        
        GeocodingManager.shared.geocodeAddress(
            address: suggestion,
            city: city,
            country: country
        ) { coordinate in
            isGeocoding = false
            
            if let coordinate = coordinate {
                geocodedCoordinate = coordinate
                print("✅ Address geocoded: \(coordinate.latitude), \(coordinate.longitude)")
            } else {
                print("❌ Failed to geocode address")
            }
        }
    }
    
    // Save business with geocoded location
    func saveBusiness() {
        // Validate required fields
        guard !name.isEmpty, !address.isEmpty, !city.isEmpty, !phone.isEmpty else {
            alertMessage = "Please fill in all required fields"
            showingAlert = true
            return
        }
        
        // If no coordinate yet, geocode now
        if geocodedCoordinate == nil {
            isGeocoding = true
            GeocodingManager.shared.geocodeAddress(
                address: address,
                city: city,
                country: country
            ) { coordinate in
                isGeocoding = false
                
                if let coordinate = coordinate {
                    geocodedCoordinate = coordinate
                    uploadAndSave()
                } else {
                    alertMessage = "Could not find location. Please check the address."
                    showingAlert = true
                }
            }
        } else {
            uploadAndSave()
        }
    }
    
    // Upload images and save business
    func uploadAndSave() {
        guard let coordinate = geocodedCoordinate else {
            alertMessage = "Location is required"
            showingAlert = true
            return
        }
        
        isUploading = true
        
        // If no images, save directly
        if selectedImages.isEmpty {
            saveBusinessToFirestore(coordinate: coordinate, photoURLs: [])
            return
        }
        
        var uploadedURLs: [String] = []
        let group = DispatchGroup()
        
        // Upload images
        for image in selectedImages {
            group.enter()
            businessViewModel.uploadImage(image, for: UUID().uuidString) { url in
                if let url = url {
                    uploadedURLs.append(url)
                }
                group.leave()
            }
        }
        
        // Wait for all uploads to complete
        group.notify(queue: .main) { [self] in
            saveBusinessToFirestore(coordinate: coordinate, photoURLs: uploadedURLs)
        }
    }
    
    // Save business to Firestore
    private func saveBusinessToFirestore(coordinate: CLLocationCoordinate2D, photoURLs: [String]) {
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
            photoURLs: photoURLs
        )
        
        // Save to Firestore
        businessViewModel.addBusiness(business) { success, message in
            isUploading = false
            alertMessage = message
            showingAlert = true
        }
    }
}
