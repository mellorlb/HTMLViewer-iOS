import Foundation
import Combine

/// Files downloaded from WKWebView remain in Documents/Downloads, visible in
/// Files > On My iPhone > HTML Viewer > Downloads when File Sharing is enabled.
@MainActor
final class DownloadLibrary: ObservableObject {
    @Published private(set) var files: [URL] = []
    @Published var latestMessage: String?

    let directory: URL
    private let manager = FileManager.default

    init() {
        directory = manager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            refresh()
        } catch {
            latestMessage = "Couldn't prepare Downloads: \(error.localizedDescription)"
        }
    }

    func refresh() {
        let urls = (try? manager.contentsOfDirectory(at: directory,
                                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                                options: [.skipsHiddenFiles])) ?? []
        files = urls.filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return a > b
            }
    }

    /// WKDownload requires a *nonexistent* destination file. Never trust a
    /// supplied filename to escape the Downloads directory or replace a file.
    func destination(for suggestedFilename: String) throws -> URL {
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        var name = suggestedFilename.replacingOccurrences(of: "\\", with: "/")
            .components(separatedBy: "/").last ?? "download"
        name = name.components(separatedBy: .controlCharacters).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name == "." || name == ".." { name = "download" }
        if name.hasPrefix(".") { name = "download" + name }
        name = String(name.prefix(180))
        let original = (name as NSString).deletingPathExtension
        let suffix = (name as NSString).pathExtension
        var candidate = directory.appendingPathComponent(name, isDirectory: false)
        var i = 2
        while manager.fileExists(atPath: candidate.path) {
            let nextName = "\(original) (\(i))" + (suffix.isEmpty ? "" : ".\(suffix)")
            candidate = directory.appendingPathComponent(nextName, isDirectory: false)
            i += 1
        }
        return candidate
    }

    func finished(_ file: URL) {
        latestMessage = "Downloaded \(file.lastPathComponent)"
        refresh()
    }

    func failed(_ error: Error) {
        latestMessage = "Download failed: \(error.localizedDescription)"
        refresh()
    }

    func delete(_ file: URL) throws {
        guard file.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL else {
            throw ImportFailure.failed("This file is outside Downloads.")
        }
        try manager.removeItem(at: file)
        refresh()
    }
}
