import Foundation

/// A listener entering .ready does not prove WebKit can retrieve content.
/// Require a successful HEAD request to the exact entry URL before switching
/// from the reliable file:// display to the full HTTP origin.
enum LocalHTTPProbe {
    static func failureReason(for url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 3
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return "The local server returned a non-HTTP response."
            }
            guard http.statusCode == 200 else {
                return "The local server returned HTTP \(http.statusCode) for the entry HTML file."
            }
            guard http.value(forHTTPHeaderField: "X-HTMLViewer-Server") == "1" else {
                return "Port \(url.port ?? 0) returned an unexpected server response."
            }
            return nil
        } catch {
            return "The local server failed its entry-page check: \(error.localizedDescription)"
        }
    }
}
