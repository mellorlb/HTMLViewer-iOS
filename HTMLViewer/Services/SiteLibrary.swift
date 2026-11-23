import Foundation
import Combine
import ZIPFoundation

@MainActor
final class SiteLibrary: ObservableObject {
    @Published private(set) var sites: [Site] = []
    @Published private(set) var isImporting = false

    private let manager = FileManager.default
    private let documents: URL
    private let metadata: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.documents = documents.appendingPathComponent("HTML Sites", isDirectory: true)
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        self.metadata = support.appendingPathComponent("sites.json")
        try? FileManager.default.createDirectory(at: self.documents, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: metadata),
           let loaded = try? JSONDecoder().decode([Site].self, from: data) {
            sites = loaded.filter { manager.fileExists(atPath: folder(for: $0).path) }
        }
    }

    func folder(for site: Site) -> URL {
        documents.appendingPathComponent(site.id.uuidString, isDirectory: true)
    }

    func importURLs(_ urls: [URL]) async throws {
        guard !urls.isEmpty else { return }
        isImporting = true
        defer { isImporting = false }

        let localDocuments = documents
        var errors: [String] = []
        for url in urls {
            do {
                let port = allocatePort()
                let newSite = try await Task.detached(priority: .userInitiated) {
                    try SiteImporter.importItem(url, into: localDocuments, port: port)
                }.value
                sites.insert(newSite, at: 0)
                save()
            } catch {
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if !errors.isEmpty {
            throw ImportFailure.failed(errors.joined(separator: "\n"))
        }
    }

    /// Creates a new editable page without using the Files picker.
    func createHTML(named rawName: String) throws -> Site {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = name.isEmpty ? "Untitled" : name
        let site = Site(name: title, entryPath: "index.html", port: allocatePort())
        let directory = folder(for: site)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            let escapedTitle = title.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
            let html = """
            <!doctype html>
            <html lang="en">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>\(escapedTitle)</title>
              <style>body { font: 16px -apple-system, sans-serif; padding: 24px; }</style>
            </head>
            <body>
              <h1>\(escapedTitle)</h1>
              <p>Tap Edit HTML to change this page.</p>
            </body>
            </html>
            """
            try html.write(to: directory.appendingPathComponent("index.html"),
                           atomically: true, encoding: .utf8)
            sites.insert(site, at: 0)
            save()
            return site
        } catch {
            try? manager.removeItem(at: directory)
            throw error
        }
    }

    func htmlPaths(for site: Site) throws -> [String] {
        let root = folder(for: site)
        guard let enumerator = manager.enumerator(at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]) else {
            throw ImportFailure.failed("Could not list this site's files.")
        }
        var paths: [String] = []
        for case let url as URL in enumerator {
            guard ["html", "htm", "xhtml"].contains(url.pathExtension.lowercased()),
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }
            let relative = String(url.path.dropFirst(root.path.count + 1))
            paths.append(relative)
        }
        return paths.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    func readHTML(for site: Site, path: String) throws -> String {
        try String(contentsOf: verifiedHTMLURL(for: site, path: path), encoding: .utf8)
    }

    func writeHTML(_ text: String, for site: Site, path: String) throws {
        let url = try verifiedHTMLURL(for: site, path: path)
        // Atomic replacement leaves a currently streaming request undamaged.
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func verifiedHTMLURL(for site: Site, path: String) throws -> URL {
        guard sites.contains(where: { $0.id == site.id }),
              !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\"),
              path.split(separator: "/").allSatisfy({ $0 != "." && $0 != ".." }),
              ["html", "htm", "xhtml"].contains((path as NSString).pathExtension.lowercased()) else {
            throw ImportFailure.failed("Invalid HTML file path.")
        }
        let root = folder(for: site).resolvingSymlinksInPath().standardizedFileURL
        let url = root.appendingPathComponent(path)
            .resolvingSymlinksInPath().standardizedFileURL
        guard url.path.hasPrefix(root.path + "/"),
              manager.fileExists(atPath: url.path),
              (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            throw ImportFailure.failed("The HTML file is missing or outside the imported site.")
        }
        return url
    }

    func update(_ site: Site) {
        guard let index = sites.firstIndex(where: { $0.id == site.id }) else { return }
        sites[index] = site
        save()
    }

    func delete(_ site: Site) {
        sites.removeAll { $0.id == site.id }
        try? manager.removeItem(at: folder(for: site))
        save()
    }

    private func allocatePort() -> UInt16 {
        let reserved = Set(sites.map(\.port))
        for _ in 0..<500 {
            let candidate = UInt16.random(in: 20000...60000)
            if !reserved.contains(candidate) { return candidate }
        }
        return UInt16.random(in: 20000...60000)
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(sites)
            try data.write(to: metadata, options: .atomic)
        } catch {
            NSLog("Failed to save site library: %@", error.localizedDescription)
        }
    }
}

enum ImportFailure: LocalizedError {
    case failed(String)
    var errorDescription: String? {
        switch self { case .failed(let reason): return reason }
    }
}

enum SiteImporter {
    static func importItem(_ externalURL: URL, into root: URL, port: UInt16) throws -> Site {
        let manager = FileManager.default
        let permitted = externalURL.startAccessingSecurityScopedResource()
        defer { if permitted { externalURL.stopAccessingSecurityScopedResource() } }

        let id = UUID()
        let target = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try manager.createDirectory(at: target, withIntermediateDirectories: true)
        do {
            let itemName = externalURL.deletingPathExtension().lastPathComponent
            let extensionName = externalURL.pathExtension.lowercased()
            let values = try externalURL.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                // Keep all relative CSS, JS, images, WASM and subfolders intact.
                let contents = try manager.contentsOfDirectory(at: externalURL,
                                                              includingPropertiesForKeys: nil)
                for item in contents {
                    try manager.copyItem(at: item,
                                         to: target.appendingPathComponent(item.lastPathComponent))
                }
            } else if extensionName == "zip" {
                // Validate paths before extracting untrusted archives.
                let archive = try Archive(url: externalURL, accessMode: .read)
                for entry in archive {
                    let path = entry.path
                    let parts = path.split(separator: "/", omittingEmptySubsequences: false)
                    guard !path.hasPrefix("/"), !path.contains("\\"),
                          !parts.contains(".."), !parts.contains(".") else {
                        throw ImportFailure.failed("ZIP contains an unsafe file path.")
                    }
                }
                try manager.unzipItem(at: externalURL, to: target)
            } else if ["html", "htm", "xhtml"].contains(extensionName) {
                try manager.copyItem(at: externalURL,
                                     to: target.appendingPathComponent(externalURL.lastPathComponent))
            } else {
                throw ImportFailure.failed("Choose an HTML file, ZIP archive, or folder.")
            }

            let entry = try findEntry(in: target)
            // Site initialization generates an ID; use the same ID as the directory.
            return Site(id: id, name: itemName.isEmpty ? "Untitled" : itemName,
                        entryPath: entry, port: port, importedAt: Date(),
                        orientation: .automatic, chrome: .toolbar)
        } catch {
            try? manager.removeItem(at: target)
            throw error
        }
    }

    private static func findEntry(in folder: URL) throws -> String {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey],
                                                  options: [.skipsHiddenFiles]) else {
            throw ImportFailure.failed("Unable to read imported content.")
        }
        var candidates: [String] = []
        for case let candidate as URL in enumerator {
            guard ["html", "htm", "xhtml"].contains(candidate.pathExtension.lowercased()) else { continue }
            let relative = String(candidate.path.dropFirst(folder.path.count + 1))
            candidates.append(relative)
        }
        guard let choice = candidates.sorted(by: { a, b in
            let aIndex = (a as NSString).lastPathComponent.lowercased() == "index.html"
            let bIndex = (b as NSString).lastPathComponent.lowercased() == "index.html"
            if aIndex != bIndex { return aIndex }
            let aDepth = a.split(separator: "/").count
            let bDepth = b.split(separator: "/").count
            return aDepth == bDepth ? a.localizedStandardCompare(b) == .orderedAscending : aDepth < bDepth
        }).first else {
            throw ImportFailure.failed("No .html or .htm file was found.")
        }
        return choice
    }
}

private extension Site {
    init(id: UUID, name: String, entryPath: String, port: UInt16, importedAt: Date,
         orientation: SiteOrientation, chrome: ChromeMode) {
        self.id = id
        self.name = name
        self.entryPath = entryPath
        self.port = port
        self.importedAt = importedAt
        self.orientation = orientation
        self.chrome = chrome
    }
}
