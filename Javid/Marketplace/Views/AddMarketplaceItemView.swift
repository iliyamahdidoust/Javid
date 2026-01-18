import SwiftUI
import CoreLocation
import FirebaseAuth
import PhotosUI

struct AddMarketplaceItemView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var marketplaceViewModel: MarketplaceViewModel
    
    // Basic fields
    @State private var title = ""
    @State private var description = ""
    @State private var price = ""
    @State private var condition: ItemCondition = .good
    @State private var postalCode = ""
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    
    // Category and subcategory
    @State private var selectedCategory: MarketplaceCategory = .electronics
    @State private var selectedSubcategory: String = ""
    
    // Photos
    @State private var selectedImages: [UIImage] = []
    @State private var showingImagePicker = false
    
    // Upload states
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    
    // Geocoding states
    @State private var isGeocoding = false
    @State private var geocodedCoordinate: CLLocationCoordinate2D?
    @State private var geocodedCity: String = ""
    @State private var geocodedProvince: String = ""
    
    // Navigation
    @State private var navigateToDetail = false
    @State private var createdItem: MarketplaceItem?
    
    var canSubmit: Bool {
        !title.isEmpty &&
        !description.isEmpty &&
        !price.isEmpty &&
        !postalCode.isEmpty &&
        selectedImages.count > 0 &&
        !isUploading
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Photos Section (Top)
                        photosSection
                        
                        // Form Fields
                        VStack(spacing: 20) {
                            titleField
                            priceField
                            categoryPicker
                            conditionPicker
                            descriptionField
                            postalCodeField
                        }
                        .padding(.horizontal, 20)
                        
                        // List Button
                        listButton
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                    }
                }
            }
            
            // Loading Overlay
            if isUploading {
                uploadingOverlay
            }
            
            // Hidden NavigationLink for navigation after creation
            if let item = createdItem {
                NavigationLink(
                    destination: MarketplaceDetailView(item: item, marketplaceViewModel: marketplaceViewModel),
                    isActive: $navigateToDetail
                ) {
                    EmptyView()
                }
                .hidden()
            }
        }
        .navigationBarHidden(true)
        .photosPicker(
            isPresented: $showingImagePicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: 5 - selectedImages.count,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImages.append(image)
                    }
                }
                selectedPhotoItems.removeAll()
            }
        }
    }
    
    // MARK: - Header Section
    
    var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 40, height: 40)
                }
                
                Spacer()
                
                Text("Create Listing")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                // Placeholder for symmetry
                Color.clear
                    .frame(width: 40, height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(AppColors.surface)
            
            Divider()
        }
    }
    
    // MARK: - Photos Section
    
    var photosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Photos")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, 20)
            
            if selectedImages.isEmpty {
                // Empty state - large add button
                Button(action: { showingImagePicker = true }) {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(AppColors.primary.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 36, weight: .light))
                                .foregroundColor(AppColors.primary)
                        }
                        
                        VStack(spacing: 4) {
                            Text("Add Photos")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("Add up to 5 photos")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .background(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                            )
                            .foregroundColor(AppColors.border.opacity(0.3))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 20)
            } else {
                // Photos grid
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Existing photos
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 160, height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                // Remove button
                                Button(action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        let _ = selectedImages.remove(at: index)
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                            .frame(width: 32, height: 32)
                                        
                                        Image(systemName: "xmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(8)
                                
                                // Primary badge
                                if index == 0 {
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Text("Cover Photo")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.black.opacity(0.6))
                                                .cornerRadius(4)
                                            Spacer()
                                        }
                                        .padding(8)
                                    }
                                }
                            }
                        }
                        
                        // Add more button
                        if selectedImages.count < 5 {
                            Button(action: { showingImagePicker = true }) {
                                VStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(AppColors.primary.opacity(0.1))
                                            .frame(width: 56, height: 56)
                                        
                                        Image(systemName: "plus")
                                            .font(.system(size: 24, weight: .semibold))
                                            .foregroundColor(AppColors.primary)
                                    }
                                    
                                    Text("Add More")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .frame(width: 160, height: 160)
                                .background(AppColors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(
                                            style: StrokeStyle(lineWidth: 2, dash: [6, 3])
                                        )
                                        .foregroundColor(AppColors.border.opacity(0.3))
                                )
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Photo count
                Text("\(selectedImages.count) / 5 photos")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Form Fields
    
    var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            TextField("What are you selling?", text: $title)
                .font(.system(size: 16))
                .padding(16)
                .background(AppColors.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    var priceField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Price")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            HStack(spacing: 12) {
                Text("$")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 30)
                
                TextField("0.00", text: $price)
                    .font(.system(size: 16))
                    .keyboardType(.decimalPad)
            }
            .padding(16)
            .background(AppColors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            Menu {
                ForEach(MarketplaceCategory.allCases, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        HStack {
                            Image(systemName: category.icon)
                            Text(category.rawValue)
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: selectedCategory.icon)
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: selectedCategory.color))
                        .frame(width: 30)
                    
                    Text(selectedCategory.rawValue)
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(16)
                .background(AppColors.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    var conditionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Condition")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            Menu {
                ForEach(ItemCondition.allCases, id: \.self) { cond in
                    Button(action: {
                        condition = cond
                    }) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cond.rawValue)
                                .font(.system(size: 15, weight: .semibold))
                            Text(cond.description)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(condition.rawValue)
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Text(condition.description)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(16)
                .background(AppColors.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            ZStack(alignment: .topLeading) {
                if description.isEmpty {
                    Text("Describe your item (condition, features, reason for selling, etc.)")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                }
                
                TextEditor(text: $description)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(minHeight: 120)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .scrollContentBackground(.hidden)
            }
            .background(AppColors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    var postalCodeField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Postal Code")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            HStack {
                TextField("Enter postal code", text: $postalCode)
                    .font(.system(size: 16))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                
                if isGeocoding {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(16)
            .background(AppColors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
            )
            
            if let coordinate = geocodedCoordinate, !geocodedCity.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.success)
                    
                    Text("\(geocodedCity), \(geocodedProvince)")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }
    
    // MARK: - List Button
    
    var listButton: some View {
        Button(action: listItem) {
            HStack(spacing: 8) {
                if !isUploading {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                }
                
                Text(isUploading ? "Creating Listing..." : "List Item")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                canSubmit
                    ? LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [AppColors.textTertiary, AppColors.textTertiary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
            )
            .cornerRadius(12)
            .shadow(
                color: canSubmit ? AppColors.primary.opacity(0.3) : Color.clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .disabled(!canSubmit)
    }
    
    // MARK: - Uploading Overlay
    
    var uploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView(value: uploadProgress)
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                    .scaleEffect(2)
                
                VStack(spacing: 8) {
                    Text("Creating your listing")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Uploading \(Int(uploadProgress * 100))%")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    // MARK: - List Item Function
    
    func listItem() {
        // Validate all fields
        guard !title.isEmpty else { return }
        guard !description.isEmpty else { return }
        guard let priceValue = Double(price), priceValue > 0 else { return }
        guard !postalCode.isEmpty else { return }
        guard selectedImages.count > 0 else { return }
        
        guard let user = Auth.auth().currentUser,
              let userName = user.displayName,
              let userEmail = user.email else {
            return
        }
        
        // Geocode postal code if not already done
        if geocodedCoordinate == nil {
            isGeocoding = true
            geocodePostalCode()
            return
        }
        
        // Start upload
        isUploading = true
        uploadProgress = 0
        
        // Upload images one by one
        var uploadedURLs: [String] = []
        
        func uploadNextImage(index: Int) {
            guard index < selectedImages.count else {
                // All images uploaded
                createMarketplaceItem(urls: uploadedURLs)
                return
            }
            
            let image = selectedImages[index]
            uploadProgress = Double(index) / Double(selectedImages.count)
            
            marketplaceViewModel.uploadImage(image) { url in
                if let url = url {
                    uploadedURLs.append(url)
                }
                
                uploadNextImage(index: index + 1)
            }
        }
        
        uploadNextImage(index: 0)
    }
    
    // MARK: - Geocode Postal Code
    
    func geocodePostalCode() {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(postalCode) { placemarks, error in
            isGeocoding = false
            
            if let error = error {
                print("❌ Geocoding error: \(error.localizedDescription)")
                return
            }
            
            if let placemark = placemarks?.first,
               let coordinate = placemark.location?.coordinate {
                geocodedCoordinate = coordinate
                geocodedCity = placemark.locality ?? ""
                geocodedProvince = placemark.administrativeArea ?? ""
                
                print("✅ Geocoded: \(postalCode) -> (\(coordinate.latitude), \(coordinate.longitude))")
                
                // Now list the item
                listItem()
            }
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
            return
        }
        
        uploadProgress = 1.0
        
        let item = MarketplaceItem(
            title: self.title,
            description: self.description,
            price: priceValue,
            category: self.selectedCategory,
            condition: self.condition,
            location: "\(geocodedCity), \(geocodedProvince)",
            city: geocodedCity,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            sellerId: user.uid,
            sellerName: userName,
            sellerEmail: userEmail,
            photoURLs: urls
        )
        
        marketplaceViewModel.addItem(item) { success, message in
            isUploading = false
            
            if success {
                // Set created item and navigate
                createdItem = item
                
                // Small delay for smooth transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    navigateToDetail = true
                }
            }
        }
    }
}
