# HTML Viewer for iOS — unsigned IPA on GitHub Actions

A native SwiftUI **local HTML / website viewer** built around WKWebView. Requires **no local Mac** to compile: GitHub Actions runs Xcode on a GitHub-hosted macOS runner and produces an **unsigned IPA**.

## Version 1.6.0: game keyboard stability and manual list ordering (build 7)

### Eaglercraft and canvas-game text entry

- **No surprise reload when localhost starts:** An imported HTML site is verified
  on disk (using the working v1.4 storage index), then the local server is probed
  **before** creating the WKWebView. The app selects HTTP or the direct-file
  fallback once. It **does not replace the running browser** when the server
  becomes ready, which previously could reset a game username or clear JS state.
  A 3-second connection timeout still opens the local file, so a failed server
  will not leave the viewer blank. The localhost port and browser data store
  remain unchanged for each imported site.
- **Stable canvas frame during the iPhone keyboard:** The viewer ignores
  SwiftUI's keyboard-safe-area resize, so showing/hiding the keyboard does not
  repeatedly shrink and expand the whole WebGL view. On a normal HTML page,
  an input near the bottom may be covered by the keyboard until you scroll.
- **Optional game keyboard helpers:** In the viewer menu, **Send Enter to game**
  simulates the Return key when a canvas game doesn't treat the iOS keyboard's
  Done button as Return. **Type into game / canvas** lets you type using a
  native iOS field, optionally clear the game's existing text, and send simulated
  key events including Enter. To make the normal iOS Done action send Enter,
  enable **Game keyboard: Enter when Done closes keyboard** in viewer settings.
  This is *off by default* and applies only for the current viewer session, to
  avoid unintentionally submitting ordinary website forms or game chat.
  Browser security means synthetic JavaScript key events cannot impersonate
  trusted keystrokes; some games will not accept them. The fallback is best effort,
  and Eaglercraft-specific success still needs an iPhone test.

### Manually reorder the saved HTML library

1. On the main library screen, **clear the search field**.
2. Tap **Reorder** in the top-left corner, drag the row handles, then tap **Done**.
3. Or long-press a row and select **Move up** / **Move down**.

Order is persisted to the existing `sites.json` metadata; page IDs, storage
folders, web data, custom URLs, editor, Downloads and HTTP share settings stay
intact. New imports still appear at the top. Filtering/searching does not allow
reordering, to prevent misplacing hidden entries.

**Update:** Same bundle ID `com.htmlviewer.fastviewer`, version **1.6.0 (build
7)**. Sign and install over v1.5.0 with the same identity. Do not uninstall
first if you want to keep previously imported data. GitHub Actions now runs a
pure-Foundation list-order regression test in addition to the path tests.

**Verification:** The Swift parser and non-iOS smoke tests run locally. iOS
compilation requires the macOS GitHub runner, and the keyboard fix must be
confirmed with the specific Eaglercraft HTML build on your phone.

## Version 1.5.0: downloads, folder hosting, Files export, draggable menu (build 6)

This version builds on the **confirmed-working v1.4.0 imported-file path fix**.

### Download files while browsing

- Uses the native iOS **WKDownload** APIs for `<a download>` links (including
  downloadable Blob files), attachment responses, and resources that WebKit
  cannot display. Page rendering stays in WKWebView.
- Files are saved persistently to **Files > On My iPhone > HTML Viewer > Downloads**.
- Open **Downloads** from the browser's top-bar download button or its ellipsis
  menu; the same Downloads item is in the library's **+** menu. Share individual
  files to another Files location, or delete them. A banner reports download
  completion/failure. Repeated filenames get a numbered suffix.
- Download support remains subject to WebKit policies, website authentication,
  CORS, permissions and iOS storage space. The app does not bypass websites'
  anti-download restrictions or guarantee all JavaScript download techniques.

### Serve a full website folder over HTTP

1. Import an entire folder or a ZIP containing the HTML and its assets.
2. Long-press the imported site > **Serve over HTTP** (or open the viewer menu).
3. Choose **Serve folder**: the whole imported project, or one of its nested
   subdirectories. The chosen folder becomes the HTTP document root.
4. Choose **Homepage**: defaults to `index.html` in that folder when available,
   otherwise pick any HTML file, including a nested page. Enter a TCP port.
5. Tap **Start HTTP server**. Visit the displayed URL such as
   `http://192.168.1.20:8080/` from another device on the same reachable Wi-Fi.

All files under that document root (HTML, CSS, JS, WASM, media, downloads, and
subfolders) are served using their normal relative URLs. `/` serves the chosen
homepage, or redirects to a nested homepage so relative assets resolve
correctly. A parent folder cannot be fetched from a selected child folder.
The HTTP server has **no authentication/TLS**; other clients on reachable
networks can read the hosted content. Keep the app in the foreground; iOS can
suspend LAN hosting when locked/backgrounded.

### Save edited source to Files

Open **Edit HTML code**, select an HTML page, and tap the **share/export icon**
(next to Save). Choose a destination in the system Files exporter. This exports
whatever is in the editor **including unsaved edits** as an `.html` file; it
**does not overwrite the original Files import** or change the app's copy. The
separate **Save** button writes changes to the app's editable local copy.

### Move the fullscreen controls

In **No top bar** and **Fullscreen** modes, drag the floating **three-dot menu**
to any position within the visible viewer area. Tap it to open navigation,
download, editor, server and display controls. The position is retained while
the current viewer is open, and stays inside the visible bounds on rotation.

### Update notes

The app bundle ID remains `com.htmlviewer.fastviewer`, with version **1.5.0
(build 6)**. Use the same signing identity and update **in place**. Do not
uninstall the existing app if you want to preserve imported HTML and web data.
The previously working direct-file-first import flow and private-localhost
HTTP upgrade logic are preserved.

**Verification:** Swift parser and pure-Foundation path tests run here; the
GitHub macOS runner must perform the actual iOS compile, and behavior still
needs real-iPhone testing.

## Version 1.4.0: fix false “imported HTML file is missing” (build 5)

**Issue addressed:** v1.3 sometimes located an imported HTML file during a
folder scan and then incorrectly rejected it as “missing” when it rebuilt the
file URL. Version 1.4 has a new `SiteDiskIndex` that keeps the **actual file URL
returned by the filesystem** instead of guessing its location from a stored
relative path. This handles differences between canonical iOS container URLs,
filesystem aliases, and names with spaces or Unicode.

- An existing entry with outdated metadata is found by scanning its own saved
  folder and its entry path is repaired automatically. **Try opening the same
  imported site after upgrading; you should not need to reimport it** if the
  original file is still physically present in the app's Documents directory.
- New imports are validated **after copying**; the app opens the copied HTML
  for reading before adding it to the library. A bad copy is reported at import
  rather than becoming a broken library entry.
- The editor and HTTP sharing code now use the same filesystem inventory.
- In any imported viewer, choose **gear / ellipsis > Local file diagnostics**
  to see the stored entry name, whether its folder exists, and which HTML pages
  the app can find. If no file is physically present, you must reimport it.
- Keeps the `com.htmlviewer.fastviewer` bundle identifier, site metadata schema,
  custom URL browsing, code editor, display controls and GitHub unsigned IPA
  workflow. Install the update **over** your existing version to retain data.

**Testing:** The new file index passes native Swift smoke tests for stale
metadata, nested paths, Unicode/special-character names, directory aliases,
and traversal protection. All Swift source files were syntax-parsed. There is
no local iOS device/Xcode to verify a complete compiled app on the phone, so
please confirm the fix with your existing imported files.

## Version 1.3.0: imported HTML startup fix (build 4)

**This version addresses the reported “Unable to open site” problem.** The
previous app waited for the private HTTP server to start before showing any
HTML. If iOS refused a listener or connection, it displayed an error even when
the imported file was physically present. Version 1.3 first opens the imported
HTML through `WKWebView.loadFileURL(_:allowingReadAccessTo:)` using its own site
folder as the allowed read scope. The direct-file viewer is not dependent on a
local server.

In parallel, the app tries the same private HTTP origin as older releases and
checks the entry document with a real HTTP request. Only after it passes this
check does the viewer switch to HTTP. If startup or navigation fails, the HTML
remains viewable directly; a **Local loading details** menu entry records the
reason. Plain HTML, CSS, canvas, and basic JavaScript can work in file mode.
ES modules, WASM fetched from URLs, `fetch()`, and some origin-dependent storage
features may require HTTP, so the app still prefers HTTP when it passes checks.

The internal listener now explicitly binds to `127.0.0.1`, avoiding fragile
checks against OS-dependent representations of accepted connections. LAN
sharing remains separate and works as before. A last-resort HTML-string
compatibility mode can display standalone source when WebKit blocks direct
file loading, although that mode may not load linked assets.

Update **in place** using the same bundle ID and signing identity to preserve
your imported files. No new app permissions are required. The project is
syntax-checked and preflighted but still needs testing with your specific iPhone.

## Version 1.2.0: open imported pages reliably + serve on a chosen HTTP port

- An imported site's entry is checked before opening. Missing/renamed entries
  are recovered from the imported directory when possible, and a meaningful
  error appears rather than an unexplained `File not found` page.
- If a rare HTTP 404 still affects the top-level HTML document, the viewer
  attempts a direct-file fallback. Plain HTML/CSS can remain viewable;
  WebAssembly, modules and fetch may be restricted in direct-file mode.
- A shared, tested URL-to-file resolver now handles spaces, `#`, `%`, Unicode,
  nested ZIP directories and directory `index.html`, and protects against
  path traversal/symlink escapes. HTTP 404 responses identify the **requested
  relative path** for debugging a missing CSS/JS/asset. This is a code-level
  fix; the original iPhone-only failure was not reproduced in this environment.
- A **separate opt-in HTTP sharing server** exposes an imported site's selected
  HTML entry and relative assets to devices on the same reachable network.
  Long-press a library item > **Serve over HTTP**, swipe it right > **Serve**,
  or open a page > gear/ellipsis > **Serve over HTTP**.
- Choose an HTML entry (for sites containing several pages), and enter any
  available TCP port **1–65535** (default 8080). Tap **Start HTTP server**.
  Copy or share the displayed URL, e.g. `http://192.168.1.20:8080/index.html`.
  The app detects your current Wi-Fi IPv4 address and has a Refresh option.
  Use **Stop HTTP server** to immediately stop sharing.
- The LAN server is **unauthenticated HTTP**, not HTTPS, and shares the site's
  included files. Don't serve private projects on untrusted networks. iOS
  normally suspends apps after backgrounding or locking: **keep the app open
  in the foreground** while serving. Wi-Fi client isolation and VPN policies
  may prevent another device from connecting.
- Existing local site ports are unchanged to preserve per-origin web storage.
  The network server is separate from the viewer's private localhost server.
  A TCP port already being used by another service cannot be shared.

### Updating from 1.1.0

Version 1.2.0 was **build 3**; the latest project is **v1.4.0 (build 5)** with the same bundle identifier
`com.htmlviewer.fastviewer`. Build and install as an upgrade using the same
sideloading identity. **Do not delete the installed app before upgrading**, as
that may erase imported files and browser storage. Sideloading utilities may
have their own reinstall/upgrade behavior; export a backup from Files if needed.

## Version 1.1.0: iPhone import fix + editor + URL browser

- Replaced SwiftUI's narrowly filtered `.fileImporter` with a native
  `UIDocumentPickerViewController`, which accepts any file type from the Files app
  and validates HTML/ZIP files after selection. This is intended to fix cases
  where the Files picker’s **Open** button did not complete selection. The
  actual behavior should still be tested on your iPhone and Files provider.
- Import one or many HTML files or ZIP archives with **+ > Import HTML / ZIP**.
  For a website folder, choose **+ > Import website folder**. If an invalid file
  is selected, the app displays a useful import error instead of silently failing.
- Long-press an imported entry > **Edit HTML**, or open a page and choose
  **gear / ellipsis > Edit HTML code**. Switch between HTML entry files in a ZIP
  or folder using the file menu. Changes save atomically to the app's copy;
  saving from the viewer reloads the local page. Unsaved changes prompt before
  switching files or pressing Done. Text is edited as UTF-8 plain text.
- **+ > New HTML page** creates a working editable page without the file picker.
- **+ > Open custom URL**, or **gear / ellipsis > Open custom URL** from a viewer.
  An address without a scheme defaults to `https://`. Remote websites use WKWebView
  and may have their own login, CORS, SSL and embedded-browser restrictions.

### Updating an existing installation

The app **bundle identifier is unchanged** (`com.htmlviewer.fastviewer`), and
the version is now **1.5.0 (build 6)**. Build and sign the
new IPA using the **same signing identity / sideloading configuration** to
attempt an in-place upgrade. **Do not delete the installed app first** if you
want to preserve your imported sites, localStorage and preferences. Some
sideloading tools reinstall instead of upgrading; back up anything important
using Files > On My iPhone > HTML Viewer before updating.

## Features

- Import multiple `.html`/`.htm`/`.xhtml` files, ZIP archives, or complete website folders with relative assets via the native iOS Files picker.
- Persist imported files in **Files > On My iPhone > HTML Viewer > HTML Sites** (subject to iOS Files app visibility).
- Each import is an independent site, with a stable localhost origin/port and persistent `localStorage`, IndexedDB, cookies, and WebKit cache when HTTP is available; direct-file compatibility mode has different storage behavior.
- Open an arbitrary HTTP/HTTPS URL directly in the viewer, or edit imported HTML source and export to Files.
- Download attachments, binary assets and supported download links to a persistent Files-visible Downloads folder.
- Select an imported folder, preferred HTML homepage and port to serve the entire website to your LAN.
- Drag the floating three-dot menu to any on-screen position in minimal/fullscreen modes.
- Standard top toolbar, **No top bar**, or **Fullscreen** (no system status bar). The latter two keep a floating ellipsis menu for exit/controls.
- Per-site **Automatic / Portrait / Landscape** preference; rotate dynamically when the OS permits.
- Safari/WebKit web runtime: CSS, JS, ES modules, canvas, WebGL, WebAssembly, fetch, WebSockets, multimedia and online requests.
- WebGPU is offered **if the OS, hardware, and WKWebView expose `navigator.gpu`**. No private browser flags are used.
- Built-in loopback HTTP server handles HTTP GET/HEAD, range requests, MIME types including `.wasm`, and blocks path traversal/symlink escapes.
- No telemetry, custom JavaScript engines, or webpage injection.

> **Network note:** Ordinary HTTPS, HTTP and WebSocket connections made by imported HTML are subject to WebKit's security, permissions, cross-origin policies and iOS network restrictions. `localhost` inside a viewed page is the **phone**, not your computer. Use your computer's reachable LAN address for servers on the computer.

## Build an IPA on GitHub without owning a Mac

1. Download and extract the entire project ZIP. Keep the **hidden `.github/workflows/build-ipa.yml`** file and `project.yml` at the repository root.
2. On [github.com/new](https://github.com/new), create a repository (for example `HTMLViewer-iOS`).
3. On Windows, install [GitHub Desktop](https://desktop.github.com/) if needed. Clone the empty repository, copy the **contents** of this project into the cloned repository folder (including `.github`), commit, then **Push origin**.
   - Alternative terminal commands, from the extracted project root:
     ```bash
     git init
     git add .
     git commit -m "Initial HTML Viewer app"
     git branch -M main
     git remote add origin https://github.com/YOUR_USERNAME/HTMLViewer-iOS.git
     git push -u origin main
     ```
4. Open the GitHub repository, select **Actions** > **Build unsigned iOS IPA** > **Run workflow** (or use the automatic run triggered by the push). If prompted, enable Actions for the repository.
5. Open the successful build run and download **HTMLViewer-unsigned-IPA** under **Artifacts**. GitHub downloads a ZIP containing `HTMLViewer-unsigned.ipa`; **extract the artifact ZIP** to obtain the IPA.
6. Install the unsigned IPA using a compatible sideloading tool that **signs it for your device** (for example [Sideloadly](https://sideloadly.io/) on Windows, with an Apple ID). A raw unsigned IPA will *not* install directly on a typical unmodified iPhone. Signing methods, Apple account limits, and expiration depend on your tool/account. Free Apple development provisioning often expires after seven days.
7. In the app, tap **+ > Import HTML / ZIP** to import pages or **+ > Import website folder** to import a complete folder. Tap a library entry to open; choose display/orientation using the gear/ellipsis menu.

### Why GitHub Actions uses a Mac

You **personally need no Mac**, but Apple's `xcodebuild` tool runs on a **GitHub-hosted macOS machine**. The workflow installs XcodeGen, generates `HTMLViewer.xcodeproj` from `project.yml`, builds the iOS device `.app` with `CODE_SIGNING_ALLOWED=NO`, packages `Payload/HTMLViewer.app` in a ZIP renamed `.ipa`, and uploads the artifact.

### Customize the app

- App name: `HTMLViewer/Info.plist`, `CFBundleDisplayName`.
- Bundle identifier: `project.yml`, `PRODUCT_BUNDLE_IDENTIFIER` (keep a unique reverse-DNS identifier when signing).
- Min iOS version: `project.yml` (currently iOS 17.0).
- Orientation/modes: `HTMLViewer/Models/Site.swift`, `HTMLViewer/Views/ViewerView.swift`.
- Data/import: `HTMLViewer/Services/SiteLibrary.swift`.
- Native file picker: `HTMLViewer/Views/DocumentImportPicker.swift`.
- HTML editor: `HTMLViewer/Views/HTMLEditorView.swift`.
- Custom URL validation: `HTMLViewer/Models/BrowserAddress.swift`.
- Web engine: `HTMLViewer/Views/BrowserWebView.swift`.
- Local HTTP server: `HTMLViewer/Services/LocalSiteServer.swift`.
- Path handling: `HTMLViewer/Services/SitePathResolver.swift` (covered by GitHub Actions tests).
- LAN sharing: `HTMLViewer/Services/LANShareManager.swift`, `HTMLViewer/Services/SiteFolderIndex.swift` and `HTMLViewer/Views/ServeSiteSheet.swift`.
- File downloads: `HTMLViewer/Services/DownloadLibrary.swift` and `HTMLViewer/Views/DownloadsView.swift`.
- HTML editor export: `HTMLViewer/Models/HTMLSourceDocument.swift`.
- To change code, commit/push: GitHub rebuilds the IPA.

### Test website included

Import `sample-site.zip` into the app (or import the `sample-site` folder). It tests CSS, ES modules, WebGL, WebAssembly over `fetch`, `localStorage` persistence, secure-context detection, WebSocket API presence and WebGPU detection. It also includes downloadable text and generated Blob samples to verify the new download flow. Reopen the sample page after incrementing the localStorage counter to verify that its persistent origin is stable.

### Import model

- **HTML file:** each selected standalone HTML becomes its own site.
- **ZIP:** all files are extracted as one site; `index.html` is preferred as an entry point.
- **Folder:** a copy of the folder's full contents becomes one site. Use folders/ZIPs when assets are stored next to HTML files or in subdirectories.
- **If a project contains multiple HTML entry pages**, open the site entry and navigate to them with its relative links, or import separately.
- Imports are copied to local storage; changing the original in iCloud/Files does not change the imported copy. Device storage sets the practical capacity.

## Technical limitations and security

- `WKWebView` is Apple's system WebKit; this is **not** a replacement for Safari's engine or a desktop Chromium instance. Native extensions, arbitrary browser flags, Chrome-only features, privileged native file access and unrestricted background execution are not guaranteed.
- WebGPU is **not guaranteed** just because a device has a GPU. iOS/WebKit may disable or restrict APIs inside embedded views.
- Some web apps require a backend server, specific origin, cross-origin headers or HTTPS. A local viewer cannot magically run server-side Node/PHP/Python or bypass remote CORS.
- Each site's localhost port remains constant so Web storage persists; a rare port collision with another local app may prevent the site from loading until it is assigned another port. Do not casually change a site's port if you need to retain its web-origin storage.
- Imported JavaScript runs with normal webpage permissions. **Only import content you trust**. Remote scripts may send data to servers, and the app permits HTTP in web content for local-project compatibility.
- The private viewer server is restricted to localhost. The **opt-in LAN server** separately serves only files under the selected imported site directory. Anyone able to connect to the LAN port can download files from that site; there is no password or TLS. A stable internal port is an origin isolation aid, **not** an authentication mechanism.
- GitHub runners and Apple toolchains change over time. If GitHub replaces its hosted runner image, update `runs-on` and re-run. GitHub Actions billing/quotas depend on your account and repo visibility.

## Repository layout

```text
HTMLViewer-iOS/
├── .github/workflows/build-ipa.yml
├── HTMLViewer/
│   ├── HTMLViewerApp.swift
│   ├── Info.plist
│   ├── Assets.xcassets/AppIcon.appiconset/
│   ├── Models/{Site,BrowserAddress}.swift
│   ├── Services/SiteLibrary.swift
│   ├── Services/{LocalSiteServer,SitePathResolver,LANShareManager}.swift
│   └── Views/{LibraryView,ViewerView,BrowserWebView,DocumentImportPicker,HTMLEditorView,ServeSiteSheet}.swift
├── scripts/{verify_project.py,RouteSmokeTest.swift}
├── project.yml
├── sample-site/         (a demonstration web project)
└── sample-site.zip      (ready to import)
```

### If the workflow fails

- **No workflow shows up:** `.github/workflows/build-ipa.yml` didn't get committed; make sure hidden dot-folders were copied.
- **Could not resolve ZIPFoundation:** GitHub's package download/network failed; rerun, or inspect Xcode's package resolver error.
- **Signing/provisioning error:** Verify that `CODE_SIGNING_ALLOWED=NO` is present and you are building the `iphoneos` destination, not trying to export a signed archive.
- **Device cannot open IPA:** First sign using your sideloading method. A raw unsigned IPA is only a compiled package.
- **Imported HTML says missing:** Open the same entry after upgrading to v1.4; if it still fails, use the viewer menu **Local file diagnostics** and report the saved entry and readable HTML count.
- **Website missing assets:** Import the entire folder or ZIP with its CSS/JS/images, not only its top-level HTML. A 404 now shows the exact relative URL that was requested.
- **HTTP sharing fails:** Try another port (for example 8080 or 9000), keep HTML Viewer foregrounded, ensure both devices are on the same reachable Wi-Fi and allow local-network access if iOS prompts.
- **WebGPU missing:** Check `navigator.gpu` in `sample-site.zip`; availability is determined by the installed WebKit/OS and device.
