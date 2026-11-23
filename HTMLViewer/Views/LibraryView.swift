import SwiftUI

private enum ViewerDestination: Identifiable {
    case site(Site)
    case url(URL)

    var id: String {
        switch self {
        case .site(let site): return "site-\(site.id.uuidString)"
        case .url(let url): return "url-\(url.absoluteString)"
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject private var library: SiteLibrary
    @EnvironmentObject private var sharing: LANShareManager
    @EnvironmentObject private var downloads: DownloadLibrary
    @State private var search = ""
    @State private var listEditMode: EditMode = .inactive
    @State private var destination: ViewerDestination?
    @State private var editingSite: Site?
    @State private var servingSite: Site?
    @State private var showDownloads = false
    @State private var pickerMode: DocumentImportPicker.Mode?
    @State private var showURLPrompt = false
    @State private var urlText = ""
    @State private var showNewHTMLPrompt = false
    @State private var newHTMLName = "Untitled"
    @State private var errorMessage: String?

    private var filtered: [Site] {
        if search.isEmpty { return library.sites }
        return library.sites.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.entryPath.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if library.sites.isEmpty && !library.isImporting {
                    ContentUnavailableView {
                        Label("Your HTML library", systemImage: "chevron.left.forwardslash.chevron.right")
                    } description: {
                        Text("Import HTML, ZIPs or site folders, create a page, or open a URL.")
                    } actions: {
                        Button("Import HTML / ZIP") { pickerMode = .files }
                            .buttonStyle(.borderedProminent)
                        Button("Open URL") { showURLPrompt = true }
                        Button("New HTML") { showNewHTMLPrompt = true }
                    }
                } else {
                    List {
                        if library.isImporting {
                            HStack(spacing: 12) {
                                ProgressView()
                                Text("Importing into local storage…")
                            }
                        }
                        ForEach(filtered) { site in
                            Button {
                                destination = .site(site)
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "curlybraces.square.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.tint)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(site.name)
                                            .foregroundStyle(.primary)
                                            .font(.headline)
                                            .lineLimit(1)
                                        Text(site.entryPath)
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                            .lineLimit(1)
                                        Text(site.importedAt, style: .date)
                                            .foregroundStyle(.tertiary)
                                            .font(.caption2)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 5)
                            }
                            .swipeActions(edge: .leading) {
                                Button("Serve", systemImage: "network") { servingSite = site }
                                    .tint(.blue)
                            }
                            .contextMenu {
                                Button("Open", systemImage: "arrow.up.right.square") {
                                    destination = .site(site)
                                }
                                Button("Edit HTML", systemImage: "chevron.left.forwardslash.chevron.right") {
                                    editingSite = site
                                }
                                Button("Serve over HTTP", systemImage: "network") {
                                    servingSite = site
                                }
                                Divider()
                                Button("Move up", systemImage: "arrow.up") {
                                    library.shift(site, by: -1)
                                }
                                .disabled(library.sites.first?.id == site.id || !search.isEmpty)
                                Button("Move down", systemImage: "arrow.down") {
                                    library.shift(site, by: 1)
                                }
                                .disabled(library.sites.last?.id == site.id || !search.isEmpty)
                                Button("Delete", role: .destructive) { delete(site) }
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { delete(filtered[index]) }
                        }
                        .onMove { offsets, destination in
                            guard search.isEmpty, !library.isImporting else { return }
                            library.reorder(fromOffsets: offsets, toOffset: destination)
                        }
                    }
                    .environment(\.editMode, $listEditMode)
                }
            }
            .navigationTitle("HTML Viewer")
            .onChange(of: search) { _, updated in
                if !updated.isEmpty { listEditMode = .inactive }
            }
            .searchable(text: $search, prompt: "Search imported pages")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !library.sites.isEmpty {
                        Button(listEditMode == .active ? "Done" : "Reorder") {
                            withAnimation {
                                listEditMode = listEditMode == .active ? .inactive : .active
                            }
                        }
                        .disabled(!search.isEmpty || library.isImporting)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Import HTML / ZIP", systemImage: "doc.badge.plus") {
                            pickerMode = .files
                        }
                        Button("Import website folder", systemImage: "folder.badge.plus") {
                            pickerMode = .folder
                        }
                        Divider()
                        Button("New HTML page", systemImage: "doc.text") {
                            showNewHTMLPrompt = true
                        }
                        Button("Open custom URL", systemImage: "globe") {
                            showURLPrompt = true
                        }
                        Divider()
                        Button("Downloads", systemImage: "arrow.down.circle") {
                            showDownloads = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(library.isImporting)
                }
            }
            .sheet(isPresented: $showDownloads) {
                DownloadsView().environmentObject(downloads)
            }
            .sheet(item: $pickerMode) { mode in
                DocumentImportPicker(mode: mode) { result in
                    pickerMode = nil
                    if let result { process(result) }
                }
            }
            .sheet(item: $editingSite) { site in
                HTMLEditorView(site: site)
                    .environmentObject(library)
            }
            .sheet(item: $servingSite) { site in
                ServeSiteSheet(site: site)
                    .environmentObject(library)
                    .environmentObject(sharing)
            }
            .fullScreenCover(item: $destination) { target in
                switch target {
                case .site(let site):
                    ViewerView(site: site).environmentObject(library)
                case .url(let url):
                    ViewerView(remoteURL: url).environmentObject(library)
                }
            }
            .alert("Open custom URL", isPresented: $showURLPrompt) {
                TextField("https://example.com", text: $urlText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                Button("Cancel", role: .cancel) {}
                Button("Open") { openCustomURL() }
            } message: {
                Text("Enter an HTTP or HTTPS address. A scheme-free address uses HTTPS.")
            }
            .alert("New HTML page", isPresented: $showNewHTMLPrompt) {
                TextField("Page name", text: $newHTMLName)
                Button("Cancel", role: .cancel) {}
                Button("Create") { createHTML() }
            } message: {
                Text("Make a new local page you can edit without importing a file.")
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .onOpenURL { url in importSelected([url]) }
        }
    }

    private func process(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls): importSelected(urls)
        case .failure(let error): errorMessage = error.localizedDescription
        }
    }

    private func importSelected(_ urls: [URL]) {
        Task {
            do { try await library.importURLs(urls) }
            catch { errorMessage = error.localizedDescription }
        }
    }

    private func delete(_ site: Site) {
        sharing.stopIfSharing(site)
        library.delete(site)
    }

    private func createHTML() {
        do {
            let site = try library.createHTML(named: newHTMLName)
            editingSite = site
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openCustomURL() {
        do {
            let url = try BrowserAddress.parse(urlText)
            destination = .url(url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
