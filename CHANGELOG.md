# Changes

## v1.2.0 — November 22, 2026

- Reworked imported HTML URL/file mapping through a standalone, tested
  `SitePathResolver`; verifies entry files before a viewer starts and attempts
  to recover obsolete/missing entry names from a copied site directory.
- Normalized percent-encoded paths, nested `index.html` routes and diagnostic
  404 messages; preserved per-site localhost origins for WebKit storage.
- Added a network-reachable, opt-in HTTP server on a chosen TCP port (1–65535),
  selectable HTML entry, copy/share URL, and stop control. Servers live at app
  scope so they can survive closing the viewer while app is foregrounded.
- Explicit warnings for unauthenticated HTTP access and iOS suspension.
- Added cross-platform routing smoke tests to GitHub Actions.
- Version bumped to 1.2.0 (build 3). Actual iOS compilation requires GitHub
  Actions/macOS; on-device verification remains necessary.

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
