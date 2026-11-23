import SwiftUI

struct ViewerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: SiteLibrary
    @EnvironmentObject private var sharing: LANShareManager
    @StateObject private var browser = BrowserState()
    @State private var pageURL: URL?
    @State private var fallbackFileURL: URL?
    @State private var server: LocalSiteServer?
    @State private var serverError: String?
    @State private var chrome: ChromeMode
    @State private var orientation: SiteOrientation
    @State private var editHTML = false
    @State private var showServerSheet = false
    @State private var showURLPrompt = false
    @State private var urlText = ""
    @State private var addressError: String?

    private let site: Site?
    private let remoteURL: URL?

    init(site: Site) {
        self.site = site
        self.remoteURL = nil
        _pageURL = State(initialValue: nil)
        _chrome = State(initialValue: site.chrome)
        _orientation = State(initialValue: site.orientation)
    }

    init(remoteURL: URL) {
        self.site = nil
        self.remoteURL = remoteURL
        _pageURL = State(initialValue: remoteURL)
        _chrome = State(initialValue: .toolbar)
        _orientation = State(initialValue: .automatic)
    }

    private var fallbackTitle: String {
        site?.name ?? remoteURL?.host ?? "Web browser"
    }

    var body: some View {
        VStack(spacing: 0) {
            if chrome == .toolbar { toolbar }
            ZStack(alignment: .topTrailing) {
                Color(uiColor: .systemBackground)
                if let pageURL {
                    BrowserWebView(url: pageURL, state: browser,
                                   fallbackFileURL: fallbackFileURL,
                                   fallbackReadAccessURL: site.map { library.folder(for: $0) })
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
                        viewerActions
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
        .sheet(isPresented: $showServerSheet) {
            if let site {
                ServeSiteSheet(site: site)
                    .environmentObject(library)
                    .environmentObject(sharing)
            }
        }
        .sheet(isPresented: $editHTML) {
            if let site {
                HTMLEditorView(site: site, onSave: {
                    // The server reads the updated HTML from disk. Reload only
                    // when still viewing the local site; preserve remote pages.
                    if browser.webView?.url?.host == "127.0.0.1" {
                        browser.reload()
                    }
                })
                .environmentObject(library)
            }
        }
        .alert("Open custom URL", isPresented: $showURLPrompt) {
            TextField("https://example.com", text: $urlText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            Button("Cancel", role: .cancel) {}
            Button("Go") { goToURL() }
        } message: {
            Text("Open an HTTP or HTTPS website in the current viewer.")
        }
        .alert("Invalid address", isPresented: Binding(
            get: { addressError != nil },
            set: { if !$0 { addressError = nil } }
        )) {
            Button("OK", role: .cancel) { addressError = nil }
        } message: {
            Text(addressError ?? "Unknown error")
        }
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
            Text(browser.title.isEmpty ? fallbackTitle : browser.title)
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
            Menu {
                viewerActions
                Divider()
                preferences
            } label: {
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
    private var viewerActions: some View {
        if site != nil {
            Button("Edit HTML code", systemImage: "chevron.left.forwardslash.chevron.right") {
                editHTML = true
            }
            Button("Serve over HTTP", systemImage: "network") {
                showServerSheet = true
            }
        }
        Button("Open custom URL", systemImage: "globe") {
            urlText = browser.webView?.url?.absoluteString ?? ""
            showURLPrompt = true
        }
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
        OrientationControl.apply(orientation)
        guard let site, server == nil else { return }
        do {
            let path = try library.resolvedEntry(for: site)
            fallbackFileURL = SitePathResolver.verifiedEntry(path: path,
                                                            under: library.folder(for: site))
            let instance = LocalSiteServer(root: library.folder(for: site),
                                           port: site.port, entryPath: path,
                                           audience: .localhost)
            instance.onReady = {
                guard let url = SitePathResolver.entryURL(path: path,
                                                          host: "127.0.0.1", port: site.port) else {
                    self.serverError = "The HTML filename cannot be opened as a URL."
                    return
                }
                self.serverError = nil
                self.pageURL = url
            }
            instance.onError = { reason in self.serverError = reason }
            server = instance
            instance.start()
        } catch {
            serverError = error.localizedDescription
        }
    }

    private func savePreferences() {
        guard var updated = site else { return }
        updated.chrome = chrome
        updated.orientation = orientation
        library.update(updated)
    }

    private func goToURL() {
        do {
            let url = try BrowserAddress.parse(urlText)
            if browser.webView == nil {
                pageURL = url
            } else {
                browser.load(url)
            }
        } catch {
            addressError = error.localizedDescription
        }
    }

    private func close() { dismiss() }
}
