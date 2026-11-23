import Foundation
@main
struct TestRouting {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("hv-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root.appendingPathComponent("nested project", isDirectory: true), withIntermediateDirectories: true)
        try "Hello".write(to: root.appendingPathComponent("My Page #1.html"), atomically: true, encoding: .utf8)
        try "Hello".write(to: root.appendingPathComponent("100% ready.html"), atomically: true, encoding: .utf8)
        try "Hello".write(to: root.appendingPathComponent("nested project/index.html"), atomically: true, encoding: .utf8)
        try "Hello".write(to: root.appendingPathComponent("nested project/日本語.html"), atomically: true, encoding: .utf8)
        let cases: [(String, String)] = [
            ("My Page #1.html", "My Page #1.html"),
            ("100% ready.html", "100% ready.html"),
            ("nested project/index.html", "nested project/index.html"),
            ("nested project/日本語.html", "nested project/日本語.html")
        ]
        for (name, path) in cases {
            let url = SitePathResolver.entryURL(path: name, host: "127.0.0.1", port: 34121)!
            let resolved = SitePathResolver.resolve(target: url.path(percentEncoded: true), under: root)
            precondition(resolved?.lastPathComponent == (path as NSString).lastPathComponent, "Failed \(url)")
            print("PASS: \(url)")
        }
        precondition(SitePathResolver.resolve(target: "/nested%20project/?foo=1", under: root)?.lastPathComponent == "index.html")
        for bad in ["/../secret.html", "/%2e%2e/secret.html", "/nested%20project/%2e%2e/%2e%2e/secrets", "/file%5cname"] {
            precondition(SitePathResolver.resolve(target: bad, under: root) == nil, "Path traversal accepted: \(bad)")
        }
        precondition(SitePathResolver.resolve(target: "/missing.html", under: root) == nil)
        // Regression: v1.3 could enumerate an existing HTML file but reject
        // the path reconstructed from URL.path, falsely claiming it was lost.
        let discovered = try SiteDiskIndex.files(in: root)
        precondition(discovered.count == 4, "Disk index must find all four HTML files")
        for item in discovered {
            precondition(FileManager.default.fileExists(atPath: item.url.path))
            precondition(SitePathResolver.safeRelativePath(item.relativePath))
            precondition(SitePathResolver.isContainedRegularFile(item.url, under: root))
        }
        let repaired = try SiteDiskIndex.preferred(in: root, storedPath: "outdated/index.html")
        precondition(repaired.url.lastPathComponent == "index.html", "Stale metadata must be repaired")
        precondition(repaired.relativePath == "nested project/index.html")
        let unusual = try SiteDiskIndex.preferred(in: root, storedPath: "My Page #1.html")
        precondition(unusual.url.lastPathComponent == "My Page #1.html")
        // A directory alias should not change the ability to find its contents.
        let alias = fm.temporaryDirectory.appendingPathComponent("hv-root-alias-\(UUID().uuidString)")
        try fm.createSymbolicLink(at: alias, withDestinationURL: root)
        defer { try? fm.removeItem(at: alias) }
        let fromAlias = try SiteDiskIndex.preferred(in: alias, storedPath: "nested project/日本語.html")
        precondition(fromAlias.url.lastPathComponent == "日本語.html", "Directory alias broke lookup")
        print("PASS: stored-file enumeration, stale entry repair and alias handling")
        let outside = fm.temporaryDirectory.appendingPathComponent("hv-outside-\(UUID().uuidString).html")
        try "Do not expose".write(to: outside, atomically: true, encoding: .utf8)
        defer { try? fm.removeItem(at: outside) }
        try fm.createSymbolicLink(at: root.appendingPathComponent("leak.html"), withDestinationURL: outside)
        precondition(SitePathResolver.resolve(target: "/leak.html", under: root) == nil)
        // The selected LAN document root can be the whole site or a child.
        let folders = try SiteFolderIndex.folders(in: root)
        precondition(folders.contains(".") && folders.contains("nested project"))
        let sharedRoot = SiteFolderIndex.containedDirectory(root: root, relativePath: "nested project")!
        precondition(SitePathResolver.resolve(target: "/index.html", under: sharedRoot)?.lastPathComponent == "index.html")
        precondition(SitePathResolver.resolve(target: "/My%20Page%20%231.html", under: sharedRoot) == nil,
                     "Sharing nested directory must not access parent files")
        precondition(SiteFolderIndex.containedDirectory(root: root, relativePath: "../") == nil)
        precondition(SiteFolderIndex.containedDirectory(root: root, relativePath: "nested project/..") == nil)
        let outsideFolder = fm.temporaryDirectory.appendingPathComponent("hv-outer-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: outsideFolder, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: outsideFolder) }
        try "private".write(to: outsideFolder.appendingPathComponent("secret.html"), atomically: true, encoding: .utf8)
        try fm.createSymbolicLink(at: root.appendingPathComponent("directory-link"), withDestinationURL: outsideFolder)
        precondition(SiteFolderIndex.containedDirectory(root: root, relativePath: "directory-link") == nil)
        precondition(SitePathResolver.resolve(target: "/directory-link/secret.html", under: root) == nil)
        print("PASS: directory-root isolation and nested symlink protection")
        print("PASS: index routes, traversal and missing-file checks")
    }
}
