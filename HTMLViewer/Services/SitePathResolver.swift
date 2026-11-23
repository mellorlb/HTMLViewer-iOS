import Foundation

/// Safe local resource path mapping for both WKWebView and the HTTP server.
enum SitePathResolver {
    static func safeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\"), !path.contains("\0") else { return false }
        return path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy {
            !$0.isEmpty && $0 != "." && $0 != ".."
        }
    }

    /// An iOS Documents URL can have multiple equivalent /var and /private/var
    /// spellings. Compare filesystem-canonical paths, never character counts of
    /// unrelated URL.path strings.
    static func relativePath(for candidate: URL, under directory: URL) -> String? {
        let roots = [directory.standardizedFileURL, directory.resolvingSymlinksInPath().standardizedFileURL]
        let candidates = [candidate.standardizedFileURL, candidate.resolvingSymlinksInPath().standardizedFileURL]
        // APFS, iCloud and document-provider locations can surface a file URL
        // via a different alias than the containing directory. Compare each
        // standardized/canonical pairing, not only one textual spelling.
        for root in roots {
            for file in candidates {
                let base = root.pathComponents
                let parts = file.pathComponents
                guard parts.count > base.count,
                      Array(parts.prefix(base.count)) == base else { continue }
                let relative = parts.dropFirst(base.count).joined(separator: "/")
                if safeRelativePath(relative) { return relative }
            }
        }
        return nil
    }

    static func isContainedRegularFile(_ candidate: URL, under directory: URL) -> Bool {
        guard relativePath(for: candidate, under: directory) != nil else { return false }
        // Canonical containment is required for an HTTP file: a symlinked
        // directory inside a shared site must not expose an outside folder.
        let canonicalRoot = directory.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        let canonicalFile = candidate.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        guard canonicalFile.count > canonicalRoot.count,
              Array(canonicalFile.prefix(canonicalRoot.count)) == canonicalRoot else { return false }
        // Do not depend on URLResourceValues.isRegularFile: on some iOS file
        // providers that property is absent even when the file is readable.
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: candidate.path),
              attrs[.type] as? FileAttributeType == .typeRegular else { return false }
        return true
    }

    static func verifiedEntry(path: String, under directory: URL) -> URL? {
        guard safeRelativePath(path) else { return nil }
        var candidate = directory
        for part in path.split(separator: "/") { candidate.appendPathComponent(String(part)) }
        return isContainedRegularFile(candidate, under: directory) ? candidate : nil
    }

    static func entryURL(path: String, host: String, port: UInt16) -> URL? {
        guard safeRelativePath(path) else { return nil }
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = Int(port)
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/%?#"))
        components.percentEncodedPath = "/" + path.split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: allowed) ?? "" }
            .joined(separator: "/")
        return components.url
    }

    static func resolve(target: String, under directory: URL) -> URL? {
        guard target.hasPrefix("/"),
              let components = URLComponents(string: "http://localhost" + target),
              let decoded = components.percentEncodedPath.removingPercentEncoding,
              decoded.hasPrefix("/"), !decoded.contains("\\"), !decoded.contains("\0") else {
            return nil
        }
        let relative = String(decoded.dropFirst())
        // A root or directory URL can resolve to an index.html page.
        let path = relative.isEmpty ? "index.html" : relative
        let direct = verifiedEntry(path: path, under: directory)
        if let direct { return direct }
        // A request to /folder/ can use the directory's index file.
        guard !relative.isEmpty else { return nil }
        let normalized = relative.hasSuffix("/") ? String(relative.dropLast()) : relative
        guard safeRelativePath(normalized) else { return nil }
        for suffix in ["index.html", "index.htm"] {
            if let index = verifiedEntry(path: normalized + "/" + suffix, under: directory) {
                return index
            }
        }
        return nil
    }
}
