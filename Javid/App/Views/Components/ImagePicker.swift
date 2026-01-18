import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage {
                parent.selectedImage = image
            } else if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// Multiple Image Picker
struct MultipleImagePicker: View {
    @Binding var selectedImages: [UIImage]
    @State private var tempImage: UIImage?
    @State private var showingPicker = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            if let image = tempImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .padding()
                
                HStack(spacing: 20) {
                    Button("Add More") {
                        selectedImages.append(image)
                        tempImage = nil
                        showingPicker = true
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Done") {
                        selectedImages.append(image)
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                Text("Select a photo")
                    .foregroundColor(.gray)
                    .onAppear {
                        showingPicker = true
                    }
            }
        }
        .sheet(isPresented: $showingPicker, onDismiss: {
            if tempImage == nil && selectedImages.isEmpty {
                dismiss()
            }
        }) {
            ImagePicker(selectedImage: $tempImage)
        }
    }
}
