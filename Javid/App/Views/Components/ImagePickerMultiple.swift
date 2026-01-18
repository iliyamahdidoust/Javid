import SwiftUI
import PhotosUI

struct ImagePickerMultiple: View {
    @Binding var selectedImages: [UIImage]
    let maxSelection: Int
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isPickerPresented = false
    
    var body: some View {
        Color.clear
            .photosPicker(
                isPresented: $isPickerPresented,
                selection: $selectedItems,
                maxSelectionCount: maxSelection,
                matching: .images
            )
            .onChange(of: selectedItems) { newItems in
                Task {
                    selectedImages.removeAll()
                    
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImages.append(image)
                        }
                    }
                    
                    // Auto-dismiss after loading images
                    if !selectedImages.isEmpty {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Automatically present the picker when the view appears
                isPickerPresented = true
            }
            .onChange(of: isPickerPresented) { isPresented in
                // Dismiss the sheet when picker is dismissed without selecting
                if !isPresented && selectedImages.isEmpty && selectedItems.isEmpty {
                    dismiss()
                }
            }
    }
}
