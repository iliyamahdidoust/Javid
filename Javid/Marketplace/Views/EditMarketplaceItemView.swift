import SwiftUI
import CoreLocation
import FirebaseAuth

struct EditMarketplaceItemView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var marketplaceViewModel: MarketplaceViewModel
    
    let item: MarketplaceItem
    
    @State private var title: String
    @State private var description: String
    @State private var price: String
    @State private var category: MarketplaceCategory
    @State private var condition: ItemCondition
    @State private var location: String
    @State private var existingPhotoURLs: [String]
    @State private var selectedImages: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var isUploading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSold: Bool
    
    // Geocoding states
    @State private var isGeocoding = false
    @State private var geocodedCoordinate: CLLocationCoordinate2D?
    
    init(item: MarketplaceItem, marketplaceViewModel: MarketplaceViewModel) {
        self.item = item
        self.marketplaceViewModel = marketplaceViewModel
        
        _title = State(initialValue: item.title)
        _description = State(initialValue: item.description)
        _price = State(initialValue: String(format: "%.2f", item.price))
        _category = State(initialValue: item.category)
        _condition = State(initialValue: item.condition)
        _location = State(initialValue: item.location)
        _existingPhotoURLs = State(initialValue: item.photoURLs)
        _isSold = State(initialValue: item.isSold)
        _geocodedCoordinate = State(initialValue: CLLocationCoordinate2D(
            latitude: item.latitude,
            longitude: item.longitude
        ))
    }
    
    var totalPhotos: Int {
        existingPhotoURLs.count + selectedImages.count
    }
    
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
                    
                    Toggle("Mark as Sold", isOn: $isSold)
                }
                
                // Description Section
                Section(header: Text("Description")) {
                    TextField("Describe your item", text: $description, axis: .vertical)
                        .lineLimit(5...10)
                }
                .listRowSeparator(.hidden)
                
                // Location Section
                Section(header: Text("Location")) {
                    HStack {
                        TextField("City/Area", text: $location)
                        
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
                    // Existing photos
                    if !existingPhotoURLs.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(existingPhotoURLs.enumerated()), id: \.offset) { index, urlString in
                                    if let url = URL(string: urlString) {
                                        ZStack(alignment: .topTrailing) {
                                            CachedAsyncImage(url: url) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 100, height: 100)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            } placeholder: {
                                                ZStack {
                                                    Color.gray.opacity(0.3)
                                                    ProgressView()
                                                }
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                            
                                            Button(action: {
                                                existingPhotoURLs.remove(at: index)
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
                    }
                    
                    // New selected photos
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
                    .disabled(totalPhotos >= 5)
                    
                    if totalPhotos > 0 {
                        Text("\(totalPhotos) / 5 photos")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateItem()
                    }
                    .disabled(isUploading || title.isEmpty || description.isEmpty || price.isEmpty || location.isEmpty)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerMultiple(selectedImages: $selectedImages, maxSelection: 5 - existingPhotoURLs.count)
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
                            Text("Updating item...")
                                .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                }
            }
            .onChange(of: location) { newValue in
                if newValue != item.location {
                    geocodedCoordinate = nil
                }
            }
        }
    }
    
    // MARK: - Update Item
    
    func updateItem() {
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
        
        guard !location.isEmpty else {
            alertMessage = "❌ Please enter location"
            showingAlert = true
            return
        }
        
        // If location changed and no coordinate, geocode now
        if location != item.location && geocodedCoordinate == nil {
            isGeocoding = true
            geocodeLocation()
            return
        }
        
        uploadAndUpdate()
    }
    
    // MARK: - Geocode Location
    
    func geocodeLocation() {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(location) { placemarks, error in
            isGeocoding = false
            
            if let error = error {
                print("❌ Geocoding error: \(error.localizedDescription)")
                alertMessage = "Could not find location. Please check and try again."
                showingAlert = true
                return
            }
            
            if let coordinate = placemarks?.first?.location?.coordinate {
                geocodedCoordinate = coordinate
                print("✅ Geocoded: \(location) -> (\(coordinate.latitude), \(coordinate.longitude))")
                uploadAndUpdate()
            } else {
                alertMessage = "Could not find location. Please be more specific."
                showingAlert = true
            }
        }
    }
    
    // MARK: - Upload and Update
    
    func uploadAndUpdate() {
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
        
        isUploading = true
        
        // Upload new images first
        let group = DispatchGroup()
        var newUploadedURLs: [String] = []
        
        for image in selectedImages {
            group.enter()
            marketplaceViewModel.uploadImage(image) { url in
                if let url = url {
                    newUploadedURLs.append(url)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Combine existing and new photo URLs
            let allPhotoURLs = self.existingPhotoURLs + newUploadedURLs
            
            // Create updated item
            var updatedItem = self.item
            updatedItem.title = self.title
            updatedItem.description = self.description
            updatedItem.price = priceValue
            updatedItem.category = self.category
            updatedItem.condition = self.condition
            updatedItem.location = self.location
            updatedItem.latitude = coordinate.latitude
            updatedItem.longitude = coordinate.longitude
            updatedItem.photoURLs = allPhotoURLs
            updatedItem.isSold = self.isSold
            
            // Update in Firestore
            self.marketplaceViewModel.updateItem(updatedItem) { success, message in
                self.isUploading = false
                self.alertMessage = message
                self.showingAlert = true
            }
        }
    }
}
