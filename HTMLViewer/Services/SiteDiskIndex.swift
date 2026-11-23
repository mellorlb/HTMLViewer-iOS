import Foundation

/// Uses URLs returned by the filesystem, rather than reconstructing an HTML
/// URL from a string derived by dropping characters from a container path.
/// Reconstructing paths can break on iOS container aliases and Unicode names.
struct StoredHTMLFile: Equatable {
    let relativePath: String
    let url: URL
}

enum SiteDiskIndex {
    static let htmlExtensions: Set<String> = ["html", "htm", "xhtml"]

    static func files(in directory: URL) throws -> [StoredHTMLFile] {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ImportFailure.failed("The imported website folder is no longer present in app storage.")
        }
        guard let walker = fm.enumerator(at: directory,
                                         includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                                         options: [.skipsHiddenFiles], errorHandler: nil) else {
            throw ImportFailure.failed("Unable to scan the imported website folder.")
        }
        var files: [StoredHTMLFile] = []
        for case let candidate as URL in walker {
            guard htmlExtensions.contains(candidate.pathExtension.lowercased()),
                  let relative = SitePathResolver.relativePath(for: candidate, under: directory),
                  SitePathResolver.safeRelativePath(relative),
                  SitePathResolver.isContainedRegularFile(candidate, under: directory) else { continue }
            files.append(StoredHTMLFile(relativePath: relative, url: candidate))
        }
        return files.sorted { a, b in
            let aIndex = a.url.lastPathComponent.lowercased() == "index.html"
            let bIndex = b.url.lastPathComponent.lowercased() == "index.html"
            if aIndex != bIndex { return aIndex }
            let aDepth = a.relativePath.split(separator: "/").count
            let bDepth = b.relativePath.split(separator: "/").count
            if aDepth != bDepth { return aDepth < bDepth }
            return a.relativePath.localizedStandardCompare(b.relativePath) == .orderedAscending
        }
    }

    static func preferred(in directory: URL, storedPath: String? = nil) throws -> StoredHTMLFile {
        // Fast path for ordinary stored entries; scan only if older metadata
        // cannot be opened by its original relative filename.
        if let storedPath, htmlExtensions.contains((storedPath as NSString).pathExtension.lowercased()),
           let file = SitePathResolver.verifiedEntry(path: storedPath, under: directory) {
            return StoredHTMLFile(relativePath: storedPath, url: file)
        }
        let entries = try files(in: directory)
        guard !entries.isEmpty else {
            throw ImportFailure.failed("No readable HTML file is currently stored for this site. Reimport the original HTML or ZIP if it was removed.")
        }
        if let storedPath {
            if let exact = entries.first(where: { $0.relativePath == storedPath }) { return exact }
            // Normalize iOS HFS+/APFS canonical Unicode variants without assuming
            // that raw path strings always use the same normalization.
            if let matching = entries.first(where: {
                $0.relativePath.precomposedStringWithCanonicalMapping == storedPath.precomposedStringWithCanonicalMapping
            }) { return matching }
        }
        return entries[0]
    }
}
