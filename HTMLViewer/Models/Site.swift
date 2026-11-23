import Foundation

enum SiteOrientation: String, Codable, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case portrait = "Portrait"
    case landscape = "Landscape"

    var id: String { rawValue }
}

enum ChromeMode: String, Codable, CaseIterable, Identifiable {
    case toolbar = "Toolbar"
    case minimal = "No top bar"
    case immersive = "Fullscreen"

    var id: String { rawValue }
}

struct Site: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var entryPath: String
    var port: UInt16
    var importedAt: Date
    var orientation: SiteOrientation
    var chrome: ChromeMode

    init(name: String, entryPath: String, port: UInt16) {
        self.id = UUID()
        self.name = name
        self.entryPath = entryPath
        self.port = port
        self.importedAt = Date()
        self.orientation = .automatic
        self.chrome = .toolbar
    }
}
