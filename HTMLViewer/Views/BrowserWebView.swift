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
    var fallbackFileURL: URL? = nil
    var fallbackReadAccessURL: URL? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state, originalURL: url,
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
        webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Preserve the running page, WebGL context, media and JS state when
        // the toolbar/orientation settings change. Never reload on view updates.
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let state: BrowserState
        private let originalURL: URL
        private let fallbackFileURL: URL?
        private let fallbackReadAccessURL: URL?
        private var hasAttemptedFallback = false

        init(state: BrowserState, originalURL: URL,
             fallbackFileURL: URL?, fallbackReadAccessURL: URL?) {
            self.state = state
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
                decisionHandler(.cancel)
                DispatchQueue.main.async {
                    webView.loadFileURL(fallbackFileURL, allowingReadAccessTo: fallbackReadAccessURL)
                }
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
            state.errorMessage = error.localizedDescription
            state.refresh()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            state.errorMessage = error.localizedDescription
            state.refresh()
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               let scheme = url.scheme?.lowercased(),
               ["tel", "mailto", "sms"].contains(scheme) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Open target=_blank links in this viewer instead of losing the tap.
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
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
