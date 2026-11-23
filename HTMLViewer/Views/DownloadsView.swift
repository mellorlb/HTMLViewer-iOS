import SwiftUI

struct DownloadsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var downloads: DownloadLibrary
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Downloaded files are saved to Files > On My iPhone > HTML Viewer > Downloads. Use Share to copy one to iCloud Drive or another folder.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if downloads.files.isEmpty {
                    ContentUnavailableView("No downloads yet", systemImage: "arrow.down.doc",
                                           description: Text("Tap a download link in the HTML viewer to save a file here."))
                } else {
                    ForEach(downloads.files, id: \.self) { file in
                        HStack(spacing: 12) {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.lastPathComponent).lineLimit(2)
                                if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                                    Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            ShareLink(item: file) {
                                Label("Share or save to Files", systemImage: "square.and.arrow.up")
                                    .labelStyle(.iconOnly)
                            }
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                do { try downloads.delete(file) }
                                catch { errorMessage = error.localizedDescription }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Refresh", systemImage: "arrow.clockwise") { downloads.refresh() }
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .onAppear { downloads.refresh() }
            .alert("Downloads", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "Unknown error") }
        }
    }
}
