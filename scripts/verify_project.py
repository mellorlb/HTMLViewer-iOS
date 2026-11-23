#!/usr/bin/env python3
"""Optional cross-platform preflight; does not replace an iOS xcodebuild."""
from pathlib import Path
import plistlib
import zipfile
import json

root = Path(__file__).resolve().parent.parent
required = [
    '.github/workflows/build-ipa.yml', 'project.yml', 'HTMLViewer/Info.plist',
    'HTMLViewer/HTMLViewerApp.swift', 'HTMLViewer/Models/Site.swift',
    'HTMLViewer/Models/BrowserAddress.swift',
    'HTMLViewer/Services/SiteLibrary.swift', 'HTMLViewer/Services/LocalSiteServer.swift',
    'HTMLViewer/Services/SitePathResolver.swift', 'HTMLViewer/Services/SiteDiskIndex.swift', 'HTMLViewer/Services/ImportFailure.swift', 'HTMLViewer/Services/LocalHTTPProbe.swift', 'HTMLViewer/Services/LANShareManager.swift',
    'HTMLViewer/Views/ServeSiteSheet.swift', 'scripts/RouteSmokeTest.swift',
    'HTMLViewer/Views/LibraryView.swift', 'HTMLViewer/Views/ViewerView.swift',
    'HTMLViewer/Views/BrowserWebView.swift',
    'HTMLViewer/Views/DocumentImportPicker.swift',
    'HTMLViewer/Views/HTMLEditorView.swift',
    'HTMLViewer/Assets.xcassets/AppIcon.appiconset/Contents.json',
    'HTMLViewer/Assets.xcassets/AppIcon.appiconset/AppIcon.png', 'sample-site.zip',
]
for path in required:
    assert (root / path).is_file(), f'Missing {path}'
plist = plistlib.loads((root / 'HTMLViewer/Info.plist').read_bytes())
assert plist['UIFileSharingEnabled']
assert plist['CFBundleShortVersionString'] == '1.4.0'
assert plist['CFBundleVersion'] == '5'
assert len(plist['UISupportedInterfaceOrientations']) >= 3
assets = json.loads((root / 'HTMLViewer/Assets.xcassets/AppIcon.appiconset/Contents.json').read_text())
assert assets['images'][0]['filename'] == 'AppIcon.png'
with zipfile.ZipFile(root / 'sample-site.zip') as demo:
    assert {'index.html', 'main.js', 'styles.css', 'answer.wasm'} <= set(demo.namelist())
viewer = (root / 'HTMLViewer/Views/ViewerView.swift').read_text()
webview = (root / 'HTMLViewer/Views/BrowserWebView.swift').read_text()
server = (root / 'HTMLViewer/Services/LocalSiteServer.swift').read_text()
assert 'pageURL = file' in viewer, 'Local viewer must start from direct file as a fallback'
assert 'LocalHTTPProbe.failureReason' in viewer, 'Local HTTP must be probed before switching'
assert 'webView.loadFileURL(url, allowingReadAccessTo: readAccessURL)' in webview
assert 'tryDirectFileFallback' in webview and 'tryHTMLStringFallback' in webview
assert 'parameters.requiredLocalEndpoint' in server, 'Internal HTTP listener must bind to loopback'
assert 'library.openableEntry(for: site)' in viewer, 'Viewer must use the actual scanned file URL'
assert 'SiteDiskIndex.preferred' in (root / 'HTMLViewer/Services/SiteLibrary.swift').read_text()
print(f'Preflight passed: {len(required)} required files, plist, app icon, fallback paths and demo ZIP')
