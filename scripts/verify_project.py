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
    'HTMLViewer/Services/SitePathResolver.swift', 'HTMLViewer/Services/LANShareManager.swift',
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
assert plist['CFBundleShortVersionString'] == '1.2.0'
assert plist['CFBundleVersion'] == '3'
assert len(plist['UISupportedInterfaceOrientations']) >= 3
assets = json.loads((root / 'HTMLViewer/Assets.xcassets/AppIcon.appiconset/Contents.json').read_text())
assert assets['images'][0]['filename'] == 'AppIcon.png'
with zipfile.ZipFile(root / 'sample-site.zip') as demo:
    assert {'index.html', 'main.js', 'styles.css', 'answer.wasm'} <= set(demo.namelist())
print(f'Preflight passed: {len(required)} required files, plist, app icon and demo ZIP')
