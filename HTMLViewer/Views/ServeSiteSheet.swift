import SwiftUI
import UIKit

struct ServeSiteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: SiteLibrary
    @EnvironmentObject private var sharing: LANShareManager

    let site: Site
    @State private var portText = "8080"
    @State private var entryPath = ""
    @State private var htmlFiles: [String] = []
    @State private var formError: String?
    @State private var knownAddresses: [String] = []

    private var active: SharedSiteSession? {
        guard sharing.session?.siteID == site.id else { return nil }
        return sharing.session
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Serve HTML") {
                    if htmlFiles.count > 1 {
                        Picker("Start page", selection: $entryPath) {
                            ForEach(htmlFiles, id: \.self) { file in
                                Text(file).tag(file)
                            }
                        }
                    } else {
                        LabeledContent("Start page", value: entryPath.isEmpty ? site.entryPath : entryPath)
                    }
                    HStack {
                        Text("TCP port")
                        Spacer()
                        TextField("8080", text: $portText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 110)
                    }
                    Text("Choose any available TCP port from 1 to 65535. Ports in use or restricted by iOS will return an error.")
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
                    } else {
                        Button("Stop HTTP server", systemImage: "stop.fill", role: .destructive) {
                            sharing.stop()
                        }
                    }
                }

                if let active {
                    Section("Open on another device") {
                        if knownAddresses.isEmpty {
                            Text("No Wi-Fi IPv4 address found. Connect the iPhone to Wi-Fi, then tap Refresh addresses.")
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
                    Section("Error") {
                        Text(message).foregroundStyle(.red)
                    }
                }

                Section("Important") {
                    Text("Anyone who can reach this address on your network can read the selected HTML project and its assets. No password or HTTPS is provided. Only serve files you are comfortable sharing.")
                    Text("Keep HTML Viewer open and in the foreground, with your iPhone and other device on a network that permits device-to-device connections. iOS can suspend this server when the app is backgrounded or the screen locks.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .navigationTitle("HTTP server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { configure() }
        }
    }

    private func configure() {
        htmlFiles = (try? library.htmlPaths(for: site)) ?? [site.entryPath]
        if htmlFiles.isEmpty { htmlFiles = [site.entryPath] }
        entryPath = active?.entryPath ?? (htmlFiles.contains(site.entryPath) ? site.entryPath : htmlFiles[0])
        portText = active.map { String($0.port) } ?? "8080"
        knownAddresses = LANAddresses.ipv4()
    }

    private func start() {
        formError = nil
        do {
            try sharing.start(site: site, entryPath: entryPath,
                              portString: portText, library: library)
        } catch {
            formError = error.localizedDescription
        }
    }
}
