import SwiftUI
import UniformTypeIdentifiers

/// Exports the *current editor buffer* (including any unsaved edits) via the
/// system Files document exporter without modifying the imported original.
struct HTMLSourceDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.html, .plainText] }
    static var writableContentTypes: [UTType] { [.html] }

    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
