import Foundation

/// Directory choices for LAN hosting. All roots must resolve inside the
/// imported site's own directory; symlinks cannot be used to expose other data.
enum SiteFolderIndex {
    static func containedDirectory(root: URL, relativePath: String) -> URL? {
        let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL
        guard relativePath == "." || SitePathResolver.safeRelativePath(relativePath) else { return nil }
        let proposed = relativePath == "." ? root :
            relativePath.split(separator: "/").reduce(root) {
                $0.appendingPathComponent(String($1), isDirectory: true)
            }
        let canonical = proposed.resolvingSymlinksInPath().standardizedFileURL
        let base = canonicalRoot.pathComponents
        let parts = canonical.pathComponents
        guard parts.count >= base.count, Array(parts.prefix(base.count)) == base else { return nil }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: proposed.path, isDirectory: &isDir),
              isDir.boolValue else { return nil }
        return proposed
    }

    static func folders(in root: URL) throws -> [String] {
        guard containedDirectory(root: root, relativePath: ".") != nil else {
            throw ImportFailure.failed("The imported website folder is missing.")
        }
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: root,
                  includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                  options: [.skipsHiddenFiles], errorHandler: nil) else { return ["."] }
        var result: [String] = ["."]
        for case let directory as URL in enumerator {
            guard let values = try? directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isDirectory == true,
                  values.isSymbolicLink != true,
                  let relative = SitePathResolver.relativePath(for: directory, under: root),
                  containedDirectory(root: root, relativePath: relative) != nil else { continue }
            result.append(relative)
        }
        return result.sorted { a, b in
            if a == "." { return true }
            if b == "." { return false }
            return a.localizedStandardCompare(b) == .orderedAscending
        }
    }
}
