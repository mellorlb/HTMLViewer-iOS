import SwiftUI

struct ViewerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: SiteLibrary
    @StateObject private var browser = BrowserState()
    @State private var pageURL: URL?
    @State private var server: LocalSiteServer?
    @State private var serverError: String?
    @State private var chrome: ChromeMode
    @State private var orientation: SiteOrientation
    private let site: Site

    init(site: Site) {
        self.site = site
        _chrome = State(initialValue: site.chrome)
        _orientation = State(initialValue: site.orientation)
    }

    var body: some View {
        VStack(spacing: 0) {
            if chrome == .toolbar {
                toolbar
            }
            ZStack(alignment: .topTrailing) {
                Color(uiColor: .systemBackground)
                if let pageURL {
                    BrowserWebView(url: pageURL, state: browser)
                } else if let serverError {
                    ContentUnavailableView("Unable to open site", systemImage: "wifi.exclamationmark",
                                           description: Text(serverError))
                } else {
                    ProgressView("Starting local viewer…")
                }

                if chrome != .toolbar {
                    Menu {
                        Button("Back to library", systemImage: "house") { close() }
                        Button("Back", systemImage: "chevron.left") { browser.back() }
                            .disabled(!browser.canGoBack)
                        Button("Forward", systemImage: "chevron.right") { browser.forward() }
                            .disabled(!browser.canGoForward)
                        Button("Reload", systemImage: "arrow.clockwise") { browser.reload() }
                        Divider()
                        preferences
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.55), in: Capsule())
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 12)
                }
                if let message = browser.errorMessage {
                    VStack {
                        Spacer()
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                            .padding()
                    }
                }
            }
        }
        .ignoresSafeArea(chrome == .immersive ? .all : [])
        .statusBarHidden(chrome == .immersive)
        .persistentSystemOverlays(chrome == .immersive ? .hidden : .automatic)
        .onAppear { startSite() }
        .onDisappear {
            server?.stop()
            server = nil
            OrientationControl.apply(.automatic)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
            }
            .accessibilityLabel("Back to library")
            Text(browser.title.isEmpty ? site.name : browser.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 2)
            Button { browser.back() } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!browser.canGoBack)
            Button { browser.forward() } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!browser.canGoForward)
            Button { browser.reload() } label: {
                Image(systemName: "arrow.clockwise")
            }
            Menu { preferences } label: {
                Image(systemName: "gearshape")
            }
        }
        .font(.body)
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    @ViewBuilder
    private var preferences: some View {
        Menu("Display mode") {
            ForEach(ChromeMode.allCases) { option in
                Button {
                    chrome = option
                    savePreferences()
                } label: {
                    if chrome == option { Label(option.rawValue, systemImage: "checkmark") }
                    else { Text(option.rawValue) }
                }
            }
        }
        Menu("Orientation") {
            ForEach(SiteOrientation.allCases) { option in
                Button {
                    orientation = option
                    OrientationControl.apply(option)
                    savePreferences()
                } label: {
                    if orientation == option { Label(option.rawValue, systemImage: "checkmark") }
                    else { Text(option.rawValue) }
                }
            }
        }
    }

    private func startSite() {
        guard server == nil else { return }
        OrientationControl.apply(orientation)
        let instance = LocalSiteServer(root: library.folder(for: site), port: site.port)
        instance.onReady = {
            var components = URLComponents()
            components.scheme = "http"
            components.host = "127.0.0.1"
            components.port = Int(site.port)
            let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "?#"))
            components.percentEncodedPath = "/" + site.entryPath.split(separator: "/")
                .map { String($0).addingPercentEncoding(withAllowedCharacters: allowed) ?? String($0) }
                .joined(separator: "/")
            self.pageURL = components.url
        }
        instance.onError = { self.serverError = $0 }
        server = instance
        instance.start()
    }

    private func savePreferences() {
        var updated = site
        updated.chrome = chrome
        updated.orientation = orientation
        library.update(updated)
    }

    private func close() { dismiss() }
}
