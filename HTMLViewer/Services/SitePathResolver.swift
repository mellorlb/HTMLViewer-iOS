import Foundation

/// A single, testable path mapping used by both the viewer and the HTTP server.
/// Keep site URLs path-based so HTML assets and page-relative links keep working.
enum SitePathResolver {
    static func entryURL(path: String, host: String, port: UInt16) -> URL? {
        guard validRelativePath(path), !path.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = Int(port)
        // Encode each component independently. Percent, hash, question mark,
        // spaces and non-ASCII file names must not change the request path.
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
        guard validRelativePath(relative) else { return nil }

        let root = directory.resolvingSymlinksInPath().standardizedFileURL
        var candidate = root
        for component in relative.split(separator: "/") {
            candidate.appendPathComponent(String(component))
        }
        // Directories are allowed only when they contain an index file.
        if (try? candidate.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            guard let index = ["index.html", "index.htm"].map({ candidate.appendingPathComponent($0) })
                .first(where: { FileManager.default.fileExists(atPath: $0.path) }) else { return nil }
            candidate = index
        }
        candidate = candidate.resolvingSymlinksInPath().standardizedFileURL
        // Path-prefix checks must include the slash: /site-a must not cover /site-attack.
        guard candidate.path.hasPrefix(root.path + "/"),
              (try? candidate.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            return nil
        }
        return candidate
    }

    static func verifiedEntry(path: String, under directory: URL) -> URL? {
        guard validRelativePath(path), !path.isEmpty else { return nil }
        let file = directory.appendingPathComponent(path).resolvingSymlinksInPath().standardizedFileURL
        let root = directory.resolvingSymlinksInPath().standardizedFileURL
        guard file.path.hasPrefix(root.path + "/"),
              (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            return nil
        }
        return file
    }

    private static func validRelativePath(_ path: String) -> Bool {
        guard !path.hasPrefix("/"), !path.contains("\\"), !path.contains("\0") else { return false }
        return path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy {
            $0 != "." && $0 != ".."
        }
    }
}
