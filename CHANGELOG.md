# Changes

## v1.3.0 — November 22, 2026

- **Fix for imported HTML showing “Unable to open site”:** The native viewer now
  opens the validated imported HTML immediately with `WKWebView.loadFileURL` and
  allows read access to that site's directory. It no longer requires an HTTP
  listener to reach `.ready` before a page can be displayed.
- Starts the private localhost server in parallel, **probes the real entry page
  with HEAD** and checks a server-specific response header. Only upgrades to
  the `http://127.0.0.1` origin after a successful probe. This maintains
  capabilities such as ES modules, `fetch`, and WASM for working HTTP sites.
- Corrected the server's loopback binding: uses the Network framework's
  required local endpoint instead of manually comparing string-rendered remote
  endpoints, which could reject valid loopback connections on iOS.
- Automatic recovery if WebKit fails to load the HTTP entry page, including
  transport failures (not just HTTP 404). Includes a final display-only
  `loadHTMLString` fallback if direct file navigation is also rejected.
- Added **Local loading details** to the viewer menu when a fallback was needed,
  so an actual error can be reported without blocking access to the HTML.
- Preserved app bundle ID, site storage, site metadata and LAN sharing feature.
  Version bumped to **1.3.0 (build 4)**.
- No physical iPhone or full Xcode toolchain available in the local workspace;
  cross-platform checks are useful but the new IPA needs on-device verification.


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
