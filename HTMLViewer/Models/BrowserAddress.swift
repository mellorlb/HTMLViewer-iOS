import Foundation

enum BrowserAddress {
    static func parse(_ raw: String) throws -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ImportFailure.failed("Enter a URL to open.")
        }
        let candidate = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              let url = components.url else {
            throw ImportFailure.failed("Enter a valid HTTP or HTTPS URL, such as https://example.com.")
        }
        return url
    }
}
