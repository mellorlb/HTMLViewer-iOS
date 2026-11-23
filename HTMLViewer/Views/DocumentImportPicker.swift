import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Use the system UIDocumentPicker directly instead of SwiftUI fileImporter.
/// Some Files providers assign imported .html documents generic UTIs, so file
/// imports allow any item and the importer validates extensions afterwards.
struct DocumentImportPicker: UIViewControllerRepresentable {
    enum Mode: String, Identifiable {
        case files
        case folder
        var id: String { rawValue }
    }

    let mode: Mode
    let onComplete: (Result<[URL], Error>?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker: UIDocumentPickerViewController
        switch mode {
        case .files:
            // Copy imported files, rather than edit originals held by iCloud
            // Drive / third-party file providers. Accept unknown file UTIs.
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
            picker.allowsMultipleSelection = true
        case .folder:
            // Folder access is security-scoped; FileManager copies the full
            // directory while that scope is active inside SiteImporter.
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
            picker.allowsMultipleSelection = false
        }
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onComplete: (Result<[URL], Error>?) -> Void

        init(onComplete: @escaping (Result<[URL], Error>?) -> Void) {
            self.onComplete = onComplete
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onComplete(.success(urls))
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onComplete(nil)
        }
    }
}
