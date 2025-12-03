import SwiftUI
import UniformTypeIdentifiers

// MARK: - Document Picker
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedDocument: URL?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Define supported file types
        let supportedTypes: [UTType] = [
            .pdf,           // PDF files
            .plainText,     // TXT files
            .epub,          // EPUB files
            .data           // For DOC/DOCX (as fallback)
        ]
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        
        // Customize appearance
        picker.shouldShowFileExtensions = true
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            print("📄 DocumentPicker: User selected document: \(url.lastPathComponent)")
            
            parent.selectedDocument = url
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("⚠️ DocumentPicker: User cancelled document selection")
        }
    }
}

