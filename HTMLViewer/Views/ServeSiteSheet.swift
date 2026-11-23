import SwiftUI
import UIKit

struct ServeSiteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: SiteLibrary
    @EnvironmentObject private var sharing: LANShareManager

    let site: Site
    @State private var portText = "8080"
    @State private var folderPath = "."
    @State private var folderPaths: [String] = ["."]
    @State private var entryPath = ""
    @State private var htmlFiles: [String] = []
    @State private var formError: String?
    @State private var knownAddresses: [String] = []

    private var active: SharedSiteSession? {
        guard sharing.session?.siteID == site.id else { return nil }
        return sharing.session
    }

    private var controlsLocked: Bool {
        active != nil || sharing.startingSiteID == site.id
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Website folder") {
                    Picker("Serve folder", selection: $folderPath) {
                        ForEach(folderPaths, id: \.self) { folder in
                            Text(folder == "." ? "Entire imported site /" : "/" + folder + "/")
                                .tag(folder)
                        }
                    }
                    .disabled(controlsLocked)
                    .onChange(of: folderPath) { _, _ in refreshPages() }
                    if htmlFiles.count > 1 {
                        Picker("Homepage", selection: $entryPath) {
                            ForEach(htmlFiles, id: \.self) { path in
                                Text(path).tag(path)
                            }
                        }
                        .disabled(controlsLocked)
                    } else {
                        LabeledContent("Homepage", value: entryPath.isEmpty ? "No HTML file" : entryPath)
                    }
                    Text("The selected folder becomes the HTTP document root. All files and subfolders inside it (CSS, JS, WASM, images, etc.) are served. Requests to / open the homepage; index.html is selected by default when present.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("HTTP server") {
                    HStack {
                        Text("TCP port")
                        Spacer()
                        TextField("8080", text: $portText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 110)
                            .disabled(controlsLocked)
                    }
                    Text("Choose an available TCP port from 1 to 65535. Restricted or occupied ports may fail.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if sharing.startingSiteID == site.id {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Starting HTTP server…")
                        }
                    } else if active == nil {
                        Button("Start HTTP server", systemImage: "network") { start() }
                            .buttonStyle(.borderedProminent)
                            .disabled(entryPath.isEmpty)
                    } else {
                        Button("Stop HTTP server", systemImage: "stop.fill", role: .destructive) {
                            sharing.stop()
                        }
                    }
                }

                if let active {
                    Section("Open on another device") {
                        LabeledContent("Serving folder", value: active.folderPath == "." ? "/" : active.folderPath)
                        LabeledContent("Default homepage", value: active.entryPath)
                        if knownAddresses.isEmpty {
                            Text("No Wi-Fi IPv4 address found. Connect to Wi-Fi, then tap Refresh addresses.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(knownAddresses, id: \.self) { ip in
                                if let url = active.address(ip: ip) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(url.absoluteString)
                                            .font(.system(.footnote, design: .monospaced))
                                            .textSelection(.enabled)
                                        HStack {
                                            Button("Copy URL", systemImage: "doc.on.doc") {
                                                UIPasteboard.general.string = url.absoluteString
                                            }
                                            Spacer()
                                            ShareLink(item: url) {
                                                Label("Share URL", systemImage: "square.and.arrow.up")
                                            }
                                        }
                                        .font(.subheadline)
                                    }
                                }
                            }
                        }
                        Button("Refresh addresses", systemImage: "arrow.clockwise") {
                            knownAddresses = LANAddresses.ipv4()
                        }
                    }
                }

                if let message = formError ?? sharing.errorMessage {
                    Section("Error") { Text(message).foregroundStyle(.red) }
                }

                Section("Important") {
                    Text("Anyone who can reach the server can read any file in the selected folder or its subfolders. This HTTP service has no password or encryption. Use trusted Wi-Fi only.")
                    Text("Keep the app in the foreground; iOS may suspend the HTTP listener when the app is backgrounded or the phone locks.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .navigationTitle("HTTP server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .onAppear { configure() }
        }
    }

    private func configure() {
        do {
            folderPaths = try library.shareableFolders(for: site)
            if folderPaths.isEmpty { folderPaths = ["."] }
            folderPath = active?.folderPath ?? "."
            if !folderPaths.contains(folderPath) { folderPath = "." }
            refreshPages(preferred: active?.entryPath)
        } catch {
            formError = error.localizedDescription
        }
        portText = active.map { String($0.port) } ?? "8080"
        knownAddresses = LANAddresses.ipv4()
    }

    private func refreshPages(preferred: String? = nil) {
        do {
            htmlFiles = try library.shareableHTMLPaths(for: site, folderPath: folderPath)
            if let preferred, htmlFiles.contains(preferred) {
                entryPath = preferred
            } else if let index = htmlFiles.first(where: { $0.lowercased() == "index.html" }) {
                entryPath = index
            } else if let index = htmlFiles.first(where: { $0.lowercased() == "index.htm" }) {
                entryPath = index
            } else {
                entryPath = htmlFiles.first ?? ""
            }
            formError = htmlFiles.isEmpty ? "This folder contains no HTML homepage. Choose another folder." : nil
        } catch {
            htmlFiles = []
            entryPath = ""
            formError = error.localizedDescription
        }
    }

    private func start() {
        formError = nil
        do {
            try sharing.start(site: site, folderPath: folderPath,
                              entryPath: entryPath, portString: portText, library: library)
        } catch {
            formError = error.localizedDescription
        }
    }
}
