import SwiftUI

/// A plain-text editor for any HTML entry page in an imported site.
/// Edits are written only to the app's private copy, not the imported original.
struct HTMLEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: SiteLibrary

    let site: Site
    var onSave: () -> Void = {}

    @State private var paths: [String] = []
    @State private var currentPath = ""
    @State private var source = ""
    @State private var savedSource = ""
    @State private var errorMessage: String?
    @State private var pendingPath: String?
    @State private var shouldCloseAfterDiscard = false
    @State private var showDiscardPrompt = false

    private var hasChanges: Bool { source != savedSource }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    if paths.count > 1 {
                        Menu {
                            ForEach(paths, id: \.self) { path in
                                Button {
                                    switchFile(to: path)
                                } label: {
                                    if path == currentPath {
                                        Label(path, systemImage: "checkmark")
                                    } else {
                                        Text(path)
                                    }
                                }
                            }
                        } label: {
                            Label(currentPath, systemImage: "doc.text")
                                .lineLimit(1)
                                .font(.subheadline)
                        }
                    } else {
                        Label(currentPath.isEmpty ? "Loading..." : currentPath,
                              systemImage: "doc.text")
                            .lineLimit(1)
                            .font(.subheadline)
                    }
                    Spacer(minLength: 4)
                    if hasChanges {
                        Text("Unsaved")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                Divider()

                TextEditor(text: $source)
                    .font(.system(size: 13, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 6)
                    .disabled(currentPath.isEmpty)
                    .accessibilityLabel("HTML source code")
            }
            .navigationTitle("HTML source editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { closeEditor() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!hasChanges || currentPath.isEmpty)
                }
            }
            .onAppear(perform: loadList)
            .confirmationDialog("Discard unsaved changes?", isPresented: $showDiscardPrompt,
                                titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) {
                    if shouldCloseAfterDiscard {
                        dismiss()
                    } else if let pendingPath {
                        read(path: pendingPath)
                    }
                    shouldCloseAfterDiscard = false
                    pendingPath = nil
                }
                Button("Keep Editing", role: .cancel) {
                    shouldCloseAfterDiscard = false
                    pendingPath = nil
                }
            } message: {
                Text("Your changes have not been saved to the HTML file.")
            }
            .alert("Unable to edit HTML", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private func loadList() {
        do {
            paths = try library.htmlPaths(for: site)
            if paths.isEmpty {
                throw ImportFailure.failed("This site has no HTML files to edit.")
            }
            read(path: paths.contains(site.entryPath) ? site.entryPath : paths[0])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func read(path: String) {
        do {
            let content = try library.readHTML(for: site, path: path)
            currentPath = path
            source = content
            savedSource = content
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func switchFile(to path: String) {
        guard path != currentPath else { return }
        if hasChanges {
            pendingPath = path
            shouldCloseAfterDiscard = false
            showDiscardPrompt = true
        } else {
            read(path: path)
        }
    }

    private func save() {
        do {
            try library.writeHTML(source, for: site, path: currentPath)
            savedSource = source
            onSave()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func closeEditor() {
        if hasChanges {
            pendingPath = nil
            shouldCloseAfterDiscard = true
            showDiscardPrompt = true
        } else {
            dismiss()
        }
    }
}
