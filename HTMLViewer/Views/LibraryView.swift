import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var library: SiteLibrary
    @State private var search = ""
    @State private var selectedSite: Site?
    @State private var importFiles = false
    @State private var importFolder = false
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
                        Text("Import HTML files, a website ZIP, or an entire folder. Pages stay on your device.")
                    } actions: {
                        Button("Import files") { importFiles = true }
                            .buttonStyle(.borderedProminent)
                        Button("Import folder") { importFolder = true }
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
                                selectedSite = site
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
                            .contextMenu {
                                Button("Open") { selectedSite = site }
                                Button("Delete", role: .destructive) { library.delete(site) }
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { library.delete(filtered[index]) }
                        }
                    }
                }
            }
            .navigationTitle("HTML Viewer")
            .searchable(text: $search, prompt: "Search imported pages")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("HTML files or ZIP", systemImage: "doc.badge.plus") {
                            importFiles = true
                        }
                        Button("Website folder", systemImage: "folder.badge.plus") {
                            importFolder = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(library.isImporting)
                }
            }
            .fileImporter(isPresented: $importFiles,
                          allowedContentTypes: [.html, UTType(filenameExtension: "htm") ?? .html, .zip],
                          allowsMultipleSelection: true) { result in
                process(result)
            }
            .fileImporter(isPresented: $importFolder,
                          allowedContentTypes: [.folder],
                          allowsMultipleSelection: true) { result in
                process(result)
            }
            .fullScreenCover(item: $selectedSite) { site in
                ViewerView(site: site)
                    .environmentObject(library)
            }
            .alert("Import error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .onOpenURL { url in
                importSelected([url])
            }
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
}
