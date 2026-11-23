# Changes

## v1.1.0 — November 22, 2026

- Native UIKit document picker replaces SwiftUI fileImporter. The file picker now
  permits any regular file classification so HTML files whose Files provider
  assigns a generic UTI can still be selected. HTML/ZIP validation happens after
  selection, and folder selection uses its own picker.
- Local HTML source editor, available from the library context menu and inside
  the viewer. HTML pages in imported ZIPs/folders can be selected from the editor.
  Saving updates the app's own UTF-8 copy atomically; the live local viewer reloads.
- New blank HTML page creation with immediate access to the editor.
- Open HTTP or HTTPS URLs from the library and from inside a viewer; supports
  HTTPS default for scheme-less addresses.
- Preserved bundle identifier, site metadata schema, per-site localhost origins,
  and existing build workflow for upgrades from v1.0.0.
- App version bumped to 1.1.0 (build 2).

This source passed syntax parsing with Swift 6.2 and the cross-platform project
preflight. Full iOS compilation must run on GitHub Actions/macOS with Xcode.
