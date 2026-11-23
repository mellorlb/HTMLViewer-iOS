import SwiftUI
import WebKit

@MainActor
final class BrowserState: ObservableObject {
    weak var webView: WKWebView?
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var title = ""
    @Published var errorMessage: String?
    @Published var fallbackDetails: String?

    func refresh() {
        guard let webView else { return }
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
        if let title = webView.title, !title.isEmpty { self.title = title }
    }

    func back() { webView?.goBack() }
    func forward() { webView?.goForward() }
    func reload() { webView?.reload() }
    func load(_ url: URL) { webView?.load(URLRequest(url: url)) }
}

struct BrowserWebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var state: BrowserState
    @ObservedObject var downloads: DownloadLibrary
    var fallbackFileURL: URL? = nil
    var fallbackReadAccessURL: URL? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state, downloads: downloads, originalURL: url,
                    fallbackFileURL: fallbackFileURL,
                    fallbackReadAccessURL: fallbackReadAccessURL)
    }

    func makeUIView(context: Context) -> WKWebView {
        let settings = WKWebViewConfiguration()
        settings.websiteDataStore = .default() // Persistent cookies, IndexedDB, localStorage.
        settings.defaultWebpagePreferences.allowsContentJavaScript = true
        settings.preferences.javaScriptCanOpenWindowsAutomatically = true
        settings.allowsInlineMediaPlayback = true
        settings.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: settings)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isInspectable = true // Inspect from Safari's Develop menu where supported.
        webView.backgroundColor = .systemBackground
        webView.isOpaque = false
        state.webView = webView
        // Imported files must use the dedicated file-loading API. Merely
        // passing a file:// URL to load(URLRequest) can be denied by WebKit.
        if url.isFileURL, let readAccessURL = fallbackReadAccessURL {
            webView.loadFileURL(url, allowingReadAccessTo: readAccessURL)
        } else {
            webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Preserve the running page, WebGL context, media and JS state when
        // the toolbar/orientation settings change. Never reload on view updates.
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
        private let state: BrowserState
        private let downloads: DownloadLibrary
        private var destinations: [ObjectIdentifier: URL] = [:]
        private let originalURL: URL
        private let fallbackFileURL: URL?
        private let fallbackReadAccessURL: URL?
        private var hasAttemptedFallback = false
        private var hasAttemptedHTMLStringFallback = false

        init(state: BrowserState, downloads: DownloadLibrary, originalURL: URL,
             fallbackFileURL: URL?, fallbackReadAccessURL: URL?) {
            self.state = state
            self.downloads = downloads
            self.originalURL = originalURL
            self.fallbackFileURL = fallbackFileURL
            self.fallbackReadAccessURL = fallbackReadAccessURL
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            // Last-resort recovery for a local HTTP 404 on the entry document.
            // A plain HTML file can still be viewed via file:// even if the
            // embedded HTTP request fails on a particular device. A site that
            // relies on fetch(), modules or WASM should use the HTTP origin.
            if !hasAttemptedFallback, navigationResponse.isForMainFrame,
               navigationResponse.response.url == originalURL,
               let http = navigationResponse.response as? HTTPURLResponse,
               http.statusCode == 404,
               let fallbackFileURL, let fallbackReadAccessURL,
               FileManager.default.fileExists(atPath: fallbackFileURL.path) {
                hasAttemptedFallback = true
                state.fallbackDetails = "Local HTTP returned 404 for the imported HTML. The original file was opened directly from app storage."
                decisionHandler(.cancel)
                DispatchQueue.main.async {
                    webView.loadFileURL(fallbackFileURL, allowingReadAccessTo: fallbackReadAccessURL)
                }
                return
            }
            if !navigationResponse.canShowMIMEType {
                decisionHandler(.download)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            state.errorMessage = nil
            state.refresh()
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            state.refresh()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            state.refresh()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if tryDirectFileFallback(webView, error: error) ||
                tryHTMLStringFallback(webView, error: error) { return }
            state.errorMessage = error.localizedDescription
            state.refresh()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            if tryDirectFileFallback(webView, error: error) ||
                tryHTMLStringFallback(webView, error: error) { return }
            state.errorMessage = error.localizedDescription
            state.refresh()
        }

        /// A listener can report .ready while WKWebView still cannot connect
        /// (port collision, local-network policy, a dropped connection, etc.).
        /// Never strand an imported page on a browser error screen.
        private func tryDirectFileFallback(_ webView: WKWebView, error: Error) -> Bool {
            guard !hasAttemptedFallback,
                  originalURL.scheme == "http",
                  let fallbackFileURL, let fallbackReadAccessURL,
                  FileManager.default.fileExists(atPath: fallbackFileURL.path) else {
                return false
            }
            // Don't redirect a failed external link to an unrelated local file.
            let failing = (error as NSError).userInfo[NSURLErrorFailingURLErrorKey] as? URL
            if let failing, failing != originalURL { return false }
            hasAttemptedFallback = true
            state.fallbackDetails = "WebKit could not load the local HTTP page: \(error.localizedDescription). The imported HTML was opened directly from app storage."
            state.errorMessage = nil
            DispatchQueue.main.async {
                webView.loadFileURL(fallbackFileURL, allowingReadAccessTo: fallbackReadAccessURL)
            }
            return true
        }

        /// Final display-only fallback if WebKit itself refuses the file URL.
        /// This can render ordinary standalone HTML, but HTTP-dependent web
        /// frameworks must still use the embedded server when available.
        private func tryHTMLStringFallback(_ webView: WKWebView, error: Error) -> Bool {
            guard !hasAttemptedHTMLStringFallback, let file = fallbackFileURL,
                  let html = try? String(contentsOf: file, encoding: .utf8) else { return false }
            let failing = (error as NSError).userInfo[NSURLErrorFailingURLErrorKey] as? URL
            guard failing?.isFileURL == true ||
                    (failing == nil && (originalURL.isFileURL || hasAttemptedFallback)) else {
                return false
            }
            hasAttemptedHTMLStringFallback = true
            state.fallbackDetails = "WebKit could not access the imported file URL. The HTML source was loaded directly from the app's copy. Linked assets and advanced web APIs may not work in this compatibility mode."
            state.errorMessage = nil
            DispatchQueue.main.async {
                webView.loadHTMLString(html, baseURL: file.deletingLastPathComponent())
            }
            return true
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               let scheme = url.scheme?.lowercased(),
               ["tel", "mailto", "sms"].contains(scheme) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else if navigationAction.shouldPerformDownload {
                decisionHandler(.download)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction,
                     didBecome download: WKDownload) {
            download.delegate = self
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse,
                     didBecome download: WKDownload) {
            download.delegate = self
        }

        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                      suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
            do {
                let destination = try downloads.destination(for: suggestedFilename)
                destinations[ObjectIdentifier(download)] = destination
                completionHandler(destination)
            } catch {
                downloads.failed(error)
                completionHandler(nil)
            }
        }

        func downloadDidFinish(_ download: WKDownload) {
            if let destination = destinations.removeValue(forKey: ObjectIdentifier(download)) {
                downloads.finished(destination)
            } else {
                downloads.refresh()
            }
        }

        func download(_ download: WKDownload, didFailWithError error: Error,
                      resumeData: Data?) {
            destinations.removeValue(forKey: ObjectIdentifier(download))
            downloads.failed(error)
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Open target=_blank links in this viewer instead of losing the tap.
            if navigationAction.targetFrame == nil {
                if navigationAction.shouldPerformDownload {
                    webView.startDownload(using: navigationAction.request) { download in
                        download.delegate = self
                    }
                } else {
                    webView.load(navigationAction.request)
                }
            }
            return nil
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void) {
            showDialog(webView, title: frame.request.url?.host ?? "JavaScript", message: message,
                       fields: false, cancel: false) { _ in completionHandler() }
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (Bool) -> Void) {
            showDialog(webView, title: "Confirm", message: message,
                       fields: false, cancel: true) { response in completionHandler(response != nil) }
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {
            showDialog(webView, title: "Input", message: prompt,
                       fields: true, cancel: true, defaultText: defaultText,
                       completion: completionHandler)
        }

        private func showDialog(_ webView: WKWebView, title: String, message: String,
                                fields: Bool, cancel: Bool, defaultText: String? = nil,
                                completion: @escaping (String?) -> Void) {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            if fields { alert.addTextField { $0.text = defaultText } }
            if cancel {
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion(nil) })
            }
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completion(fields ? alert.textFields?.first?.text ?? "" : "OK")
            })
            var presenter = webView.window?.rootViewController
            while let shown = presenter?.presentedViewController { presenter = shown }
            if let presenter { presenter.present(alert, animated: true) }
            else { completion(nil) }
        }
    }
}
