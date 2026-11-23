import Foundation
import Network
import UniformTypeIdentifiers

/// Internal sites use localhost-only mode and keep stable origin/port for web
/// storage; opt-in sharing creates a separate listener on a user-selected port.
final class LocalSiteServer {
    enum Audience { case localhost, network }

    private let root: URL
    private let port: UInt16
    private let entryPath: String
    private let audience: Audience
    private let queue = DispatchQueue(label: "HTMLViewer.HTTP", qos: .userInitiated)
    private var listener: NWListener?

    /// Invoked on the main queue; the owner must keep this object alive.
    var onReady: (() -> Void)?
    var onError: ((String) -> Void)?

    init(root: URL, port: UInt16, entryPath: String, audience: Audience = .localhost) {
        self.root = root.resolvingSymlinksInPath().standardizedFileURL
        self.port = port
        self.entryPath = entryPath
        self.audience = audience
    }

    func start() {
        guard (try? SiteDiskIndex.preferred(in: root, storedPath: entryPath)) != nil else {
            DispatchQueue.main.async { [weak self] in
                self?.onError?("The HTML entry file was not found in the imported site. Reimport or edit the site.")
            }
            return
        }
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            DispatchQueue.main.async { [weak self] in self?.onError?("Invalid TCP port.") }
            return
        }
        do {
            let parameters = NWParameters.tcp
            // Local site origins never accept a connection from another device.
            // Network mode intentionally binds reachable interfaces.
            parameters.acceptLocalOnly = (audience == .localhost)
            if audience == .localhost {
                // Bind to loopback itself, not all interfaces. The previous
                // peer-string comparison could reject legitimate WKWebView
                // connections on iOS because Network.framework may render
                // the accepted endpoint differently on different OS releases.
                parameters.requiredLocalEndpoint = .hostPort(
                    host: "127.0.0.1", port: endpointPort
                )
            }
            let listener = try NWListener(using: parameters, on: endpointPort)
            self.listener = listener
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    DispatchQueue.main.async { self.onReady?() }
                case .failed(let error):
                    DispatchQueue.main.async { self.onError?(error.localizedDescription) }
                case .cancelled: break
                default: break
                }
            }
            listener.start(queue: queue)
        } catch {
            DispatchQueue.main.async { [weak self] in self?.onError?(error.localizedDescription) }
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        onReady = nil
        onError = nil
    }

    private func accept(_ connection: NWConnection) {
        // In localhost mode the listener is bound to 127.0.0.1 above, so no
        // fragile string matching against connection.endpoint is needed.
        let handler = HTTPClient(connection: connection, root: root, entryPath: entryPath)
        handler.start(on: queue)
    }
}

private final class HTTPClient {
    private let connection: NWConnection
    private let root: URL
    private let entryPath: String
    private var received = Data()
    private var handle: FileHandle?
    private var bytesRemaining: UInt64 = 0

    init(connection: NWConnection, root: URL, entryPath: String) {
        self.connection = connection
        self.root = root
        self.entryPath = entryPath
    }

    func start(on queue: DispatchQueue) {
        connection.stateUpdateHandler = { [self] state in
            switch state {
            case .ready: self.readRequest()
            case .failed, .cancelled:
                try? self.handle?.close()
                self.handle = nil
                self.connection.stateUpdateHandler = nil
            default: break
            }
        }
        connection.start(queue: queue)
    }

    private func readRequest() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) {
            [self] data, _, isComplete, error in
            if let data { received.append(data) }
            if received.count > 32 * 1024 {
                respond(status: 431, body: "Request header too large")
                return
            }
            if let range = received.range(of: Data("\r\n\r\n".utf8)) {
                handleRequest(received.subdata(in: 0..<range.lowerBound))
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                readRequest()
            }
        }
    }

    private func handleRequest(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else {
            respond(status: 400, body: "Invalid HTTP header encoding")
            return
        }
        let lines = text.components(separatedBy: "\r\n")
        guard let first = lines.first else { respond(status: 400, body: "Bad request"); return }
        let parts = first.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count == 3, parts[2].hasPrefix("HTTP/") else {
            respond(status: 400, body: "Bad request")
            return
        }
        let method = String(parts[0])
        guard method == "GET" || method == "HEAD" else {
            respond(status: 405, body: "Only GET / HEAD are supported")
            return
        }
        let requestTarget = String(parts[1])
        // The selected homepage is available at /. For a homepage located in
        // a nested directory, redirect to its real path so relative CSS/JS
        // links correctly resolve against that directory.
        var target = requestTarget
        if requestTarget == "/" || requestTarget.hasPrefix("/?") {
            guard let url = SitePathResolver.entryURL(path: entryPath, host: "localhost", port: 1) else {
                respond(status: 500, body: "Invalid entry path")
                return
            }
            let encodedPath = url.path(percentEncoded: true)
            if entryPath.contains("/") {
                redirect(to: encodedPath)
                return
            }
            target = encodedPath
        }

        guard let file = SitePathResolver.resolve(target: target, under: root) else {
            // Never leak app-container paths into a response. Display the URL
            // being requested, so missing assets can be diagnosed on-device.
            respond(status: 404, body: "File not found: \(requestTarget)")
            return
        }

        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
            guard let number = attrs[.size] as? NSNumber else { throw CocoaError(.fileReadUnknown) }
            let size = number.uint64Value
            var start: UInt64 = 0
            var end = size > 0 ? size - 1 : 0
            var status = 200
            if let header = lines.dropFirst().first(where: { $0.lowercased().hasPrefix("range:") }) {
                guard size > 0, let range = parseRange(String(header.dropFirst(6)), size: size) else {
                    sendHeader(status: 416, extra: ["Content-Range: bytes */\(size)"], length: 0)
                    return
                }
                (start, end) = range
                status = 206
            }
            let length = size == 0 ? 0 : end - start + 1
            var extra = [
                "Content-Type: \(mimeType(file))",
                "X-HTMLViewer-Server: 1",
                "X-Content-Type-Options: nosniff",
                "Accept-Ranges: bytes",
                "Cache-Control: no-cache"
            ]
            if status == 206 { extra.append("Content-Range: bytes \(start)-\(end)/\(size)") }
            guard method != "HEAD", length > 0 else {
                sendHeader(status: status, extra: extra, length: length)
                return
            }
            handle = try FileHandle(forReadingFrom: file)
            try handle?.seek(toOffset: start)
            bytesRemaining = length
            sendHeader(status: status, extra: extra, length: length, close: false) { [self] in
                sendNextChunk()
            }
        } catch {
            respond(status: 500, body: "Unable to read imported file: \(error.localizedDescription)")
        }
    }

    private func redirect(to encodedPath: String) {
        sendHeader(status: 302, extra: ["Location: \(encodedPath)", "Cache-Control: no-cache"], length: 0)
    }

    private func sendNextChunk() {
        guard bytesRemaining > 0 else {
            try? handle?.close()
            handle = nil
            connection.cancel()
            return
        }
        do {
            let data = try handle?.read(upToCount: Int(min(bytesRemaining, 128 * 1024))) ?? Data()
            guard !data.isEmpty else { connection.cancel(); return }
            bytesRemaining -= UInt64(data.count)
            connection.send(content: data, completion: .contentProcessed { [self] error in
                if error == nil { sendNextChunk() } else { connection.cancel() }
            })
        } catch {
            connection.cancel()
        }
    }

    private func parseRange(_ raw: String, size: UInt64) -> (UInt64, UInt64)? {
        let value = raw.trimmingCharacters(in: .whitespaces)
        guard value.hasPrefix("bytes="), !value.contains(",") else { return nil }
        let chunks = value.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
        guard chunks.count == 2 else { return nil }
        if chunks[0].isEmpty {
            guard let suffix = UInt64(chunks[1]), suffix > 0 else { return nil }
            return (size - min(suffix, size), size - 1)
        }
        guard let start = UInt64(chunks[0]), start < size else { return nil }
        let end = chunks[1].isEmpty ? size - 1 : UInt64(chunks[1])
        guard let end, end >= start else { return nil }
        return (start, min(end, size - 1))
    }

    private func mimeType(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "html", "htm", "xhtml": return "text/html; charset=utf-8"
        case "js", "mjs", "cjs": return "text/javascript; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "wasm": return "application/wasm"
        case "json", "map": return "application/json"
        case "svg": return "image/svg+xml"
        case "glb": return "model/gltf-binary"
        case "gltf": return "model/gltf+json"
        case "wgsl": return "text/plain"
        default:
            return UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        }
    }

    private func respond(status: Int, body: String) {
        let payload = Data(body.utf8)
        sendHeader(status: status, extra: ["Content-Type: text/plain; charset=utf-8"],
                   length: UInt64(payload.count), close: false) { [self] in
            connection.send(content: payload, completion: .contentProcessed { _ in
                self.connection.cancel()
            })
        }
    }

    private func sendHeader(status: Int, extra: [String], length: UInt64,
                            close: Bool = true, after: (() -> Void)? = nil) {
        let reason: String
        switch status {
        case 200: reason = "OK"
        case 206: reason = "Partial Content"
        case 302: reason = "Found"
        case 400: reason = "Bad Request"
        case 404: reason = "Not Found"
        case 405: reason = "Method Not Allowed"
        case 416: reason = "Range Not Satisfiable"
        case 431: reason = "Request Header Fields Too Large"
        default: reason = "Server Error"
        }
        let headers = (["HTTP/1.1 \(status) \(reason)",
                        "Content-Length: \(length)",
                        "Connection: close"] + extra).joined(separator: "\r\n") + "\r\n\r\n"
        connection.send(content: Data(headers.utf8), completion: .contentProcessed { [self] error in
            guard error == nil else { connection.cancel(); return }
            if let after { after() } else if close { connection.cancel() }
        })
    }
}
