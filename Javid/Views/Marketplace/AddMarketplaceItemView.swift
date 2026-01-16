import SwiftUI
import CoreLocation
import FirebaseAuth

struct AddMarketplaceItemView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var marketplaceViewModel: MarketplaceViewModel
    
    @State private var title = ""
    @State private var description = ""
    @State private var price = ""
    @State private var category: MarketplaceCategory = .electronics
    @State private var condition: ItemCondition = .good
    @State private var city = ""
    @State private var location = ""
    @State private var selectedImages: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var isUploading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // Geocoding states
    @State private var isGeocoding = false
    @State private var geocodedCoordinate: CLLocationCoordinate2D?
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Info Section
                Section(header: Text("Basic Information")) {
                    TextField("Item Title", text: $title)
                    
                    Picker("Category", selection: $category) {
                        ForEach(MarketplaceCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                    
                    TextField("Price ($)", text: $price)
                        .keyboardType(.decimalPad)
                    
                    Picker("Condition", selection: $condition) {
                        ForEach(ItemCondition.allCases, id: \.self) { condition in
                            Text(condition.rawValue).tag(condition)
                        }
                    }
                }
                
                // Description Section
                Section(header: Text("Description")) {
                    TextField("Describe your item", text: $description, axis: .vertical)
                        .lineLimit(5...10)
                }
                .listRowSeparator(.hidden)
                
                // Location Section
                Section(header: Text("Location")) {
                    TextField("City", text: $city)
                    
                    HStack {
                        TextField("Area/Neighborhood", text: $location)
                        
                        if isGeocoding {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    if let coordinate = geocodedCoordinate {
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
                }
                
                // Photos Section
                Section(header: Text("Photos (Up to 5)")) {
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
                
                // Condition Info
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Condition: \(condition.rawValue)")
                            .font(.headline)
                        Text(condition.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("List an Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("List") {
                        listItem()
                    }
                    .disabled(isUploading || title.isEmpty || description.isEmpty || price.isEmpty || city.isEmpty || location.isEmpty)
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
                            Text("Listing your item...")
                                .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                }
            }
            .onChange(of: location) { newValue in
                // Reset geocoded coordinate when location changes
                geocodedCoordinate = nil
            }
            .onChange(of: city) { newValue in
                // Reset geocoded coordinate when city changes
                geocodedCoordinate = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            print("⚠️ Memory warning received - clearing selected images")
            // Don't clear images while uploading
            if !isUploading {
                selectedImages.removeAll()
            }
        }
    }
    
    // MARK: - List Item
    
    func listItem() {
        // Validation
        guard !title.isEmpty else {
            alertMessage = "❌ Please enter item title"
            showingAlert = true
            return
        }
        
        guard !description.isEmpty else {
            alertMessage = "❌ Please enter description"
            showingAlert = true
            return
        }
        
        guard let priceValue = Double(price), priceValue > 0 else {
            alertMessage = "❌ Please enter a valid price"
            showingAlert = true
            return
        }
        
        guard !city.isEmpty else {
            alertMessage = "❌ Please enter city"
            showingAlert = true
            return
        }
        
        guard !location.isEmpty else {
            alertMessage = "❌ Please enter area/neighborhood"
            showingAlert = true
            return
        }
        
        guard let user = Auth.auth().currentUser,
              let userName = user.displayName,
              let userEmail = user.email else {
            alertMessage = "❌ User information not found"
            showingAlert = true
            return
        }
        
        // If no coordinate yet, geocode now
        if geocodedCoordinate == nil {
            isGeocoding = true
            geocodeLocation()
            return
        }
        
        uploadAndList()
    }
    
    // MARK: - Geocode Location
    
    func geocodeLocation() {
        let fullAddress = "\(location), \(city)"
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(fullAddress) { placemarks, error in
            isGeocoding = false
            
            if let error = error {
                print("❌ Geocoding error: \(error.localizedDescription)")
                alertMessage = "Could not find location. Please check and try again."
                showingAlert = true
                return
            }
            
            if let coordinate = placemarks?.first?.location?.coordinate {
                geocodedCoordinate = coordinate
                print("✅ Geocoded: \(fullAddress) -> (\(coordinate.latitude), \(coordinate.longitude))")
                uploadAndList()
            } else {
                alertMessage = "Could not find location. Please be more specific."
                showingAlert = true
            }
        }
    }
    
    // MARK: - Upload and List
    
    func uploadAndList() {
        guard let coordinate = geocodedCoordinate else {
            alertMessage = "❌ Location not verified"
            showingAlert = true
            return
        }
        
        guard let priceValue = Double(price) else {
            alertMessage = "❌ Invalid price"
            showingAlert = true
            return
        }
        
        guard let user = Auth.auth().currentUser,
              let userName = user.displayName,
              let userEmail = user.email else {
            alertMessage = "❌ User information not found"
            showingAlert = true
            return
        }
        
        isUploading = true
        
        // MEMORY FIX: Upload images ONE AT A TIME instead of all at once
        var uploadedURLs: [String] = []
        
        func uploadNextImage(index: Int) {
            guard index < selectedImages.count else {
                // All images uploaded, create item
                createMarketplaceItem(urls: uploadedURLs)
                return
            }
            
            let image = selectedImages[index]
            
            marketplaceViewModel.uploadImage(image) { url in
                if let url = url {
                    uploadedURLs.append(url)
                }
                
                // Upload next image
                uploadNextImage(index: index + 1)
            }
        }
        
        // Start uploading first image
        if selectedImages.isEmpty {
            createMarketplaceItem(urls: [])
        } else {
            uploadNextImage(index: 0)
        }
    }
    
    // MARK: - Create Marketplace Item
    
    private func createMarketplaceItem(urls: [String]) {
        guard let coordinate = geocodedCoordinate,
              let priceValue = Double(price),
              let user = Auth.auth().currentUser,
              let userName = user.displayName,
              let userEmail = user.email else {
            isUploading = false
            alertMessage = "❌ Missing required information"
            showingAlert = true
            return
        }
        
        // FIXED: Correct parameter order matching the new initializer
        let item = MarketplaceItem(
            title: self.title,
            description: self.description,
            price: priceValue,
            category: self.category,
            condition: self.condition,
            location: self.location,       // Area/neighborhood
            city: self.city,                // City
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            sellerId: user.uid,
            sellerName: userName,
            sellerEmail: userEmail,
            photoURLs: urls
        )
        
        // Add to Firestore
        self.marketplaceViewModel.addItem(item) { success, message in
            self.isUploading = false
            self.alertMessage = message
            self.showingAlert = true
        }
    }
}
