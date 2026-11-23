import Foundation
import Combine
import Darwin

struct SharedSiteSession: Equatable {
    let siteID: UUID
    let name: String
    let entryPath: String
    let port: UInt16

    func address(ip: String) -> URL? {
        SitePathResolver.entryURL(path: entryPath, host: ip, port: port)
    }
}

/// Lives at app scope, not viewer scope, so a share survives closing a page.
/// Deliberately stops when iOS suspends the application; no background-service
/// or always-on hosting claims are made.
@MainActor
final class LANShareManager: ObservableObject {
    @Published private(set) var session: SharedSiteSession?
    @Published private(set) var startingSiteID: UUID?
    @Published private(set) var errorMessage: String?

    private var listener: LocalSiteServer?

    func start(site: Site, entryPath: String, portString: String, library: SiteLibrary) throws {
        let cleaned = portString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let number = UInt16(cleaned), number > 0 else {
            throw ImportFailure.failed("Choose a TCP port from 1 to 65535.")
        }
        let root = library.folder(for: site)
        guard SitePathResolver.verifiedEntry(path: entryPath, under: root) != nil else {
            throw ImportFailure.failed("The selected HTML file is missing. Choose another file or reimport the site.")
        }
        // A listener on all interfaces can conflict with an internal localhost
        // site using the same port. Report errors rather than changing origins.
        stop()
        errorMessage = nil
        startingSiteID = site.id
        let next = SharedSiteSession(siteID: site.id, name: site.name,
                                     entryPath: entryPath, port: number)
        let server = LocalSiteServer(root: root, port: number,
                                     entryPath: entryPath, audience: .network)
        listener = server
        server.onReady = { [weak self, weak server] in
            guard let self, self.listener === server else { return }
            self.startingSiteID = nil
            self.session = next
        }
        server.onError = { [weak self, weak server] reason in
            guard let self, self.listener === server else { return }
            self.errorMessage = "Couldn't start HTTP server on port \(number): \(reason)"
            self.stop(keepError: true)
        }
        server.start()
    }

    func stopIfSharing(_ site: Site) {
        if session?.siteID == site.id || startingSiteID == site.id { stop() }
    }

    func stop(keepError: Bool = false) {
        listener?.stop()
        listener = nil
        session = nil
        startingSiteID = nil
        if !keepError { errorMessage = nil }
    }
}

/// Local Wi-Fi/ethernet IPv4 addresses; never assumes a hard-coded phone IP.
enum LANAddresses {
    static func ipv4() -> [String] {
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0 else { return [] }
        defer { if let first { freeifaddrs(first) } }
        var candidates: [(String, String)] = []
        var current = first
        while let pointer = current {
            let info = pointer.pointee
            current = info.ifa_next
            guard let address = info.ifa_addr,
                  address.pointee.sa_family == sa_family_t(AF_INET),
                  (info.ifa_flags & UInt32(IFF_UP)) != 0,
                  (info.ifa_flags & UInt32(IFF_LOOPBACK)) == 0 else { continue }
            let name = String(cString: info.ifa_name)
            // en0 is standard Wi-Fi on iPhone. Some hardware/OS versions
            // expose a different en interface or bridge for local networks.
            guard name.hasPrefix("en") || name.hasPrefix("bridge") else { continue }
            let sockaddr = UnsafeRawPointer(address).assumingMemoryBound(to: sockaddr_in.self)
            var addressValue = sockaddr.pointee.sin_addr
            var bytes = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            let rendered = withUnsafePointer(to: &addressValue) { pointer in
                inet_ntop(AF_INET, pointer, &bytes, socklen_t(bytes.count))
            }
            if rendered != nil {
                candidates.append((name, String(cString: bytes)))
            }
        }
        // Wi-Fi first, then other usable network addresses.
        return candidates.sorted { ($0.0 == "en0" ? 0 : 1) < ($1.0 == "en0" ? 0 : 1) }
            .map(\.1)
            .reduce(into: [String]()) { result, item in
                if !result.contains(item) { result.append(item) }
            }
    }
}
