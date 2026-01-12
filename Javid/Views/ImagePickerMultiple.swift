import SwiftUI
import PhotosUI

struct ImagePickerMultiple: View {
    @Binding var selectedImages: [UIImage]
    let maxSelection: Int
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedItems: [PhotosPickerItem] = []
    
    var body: some View {
        NavigationView {
            VStack {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: maxSelection,
                    matching: .images
                ) {
                    Label("Select Photos", systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding()
                }
                
                if !selectedImages.isEmpty {
                    Text("\(selectedImages.count) photo(s) selected")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .navigationTitle("Select Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedItems) { newItems in
                Task {
                    selectedImages.removeAll()
                    
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImages.append(image)
                        }
                    }
                }
            }
        }
    }
}
