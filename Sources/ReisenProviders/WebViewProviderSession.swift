import WebKit

/// Generic provider session that wraps the embedded `WKWebView`.
@MainActor
public final class WebViewProviderSession: ProviderSession {
    public let webView: WKWebView
    /// Hub-/UI-Navigationshints (z. B. `lastURLString`), unabhängig von `webView.url`.
    public let navigationHintURLs: [URL]

    public init(webView: WKWebView, navigationHintURLs: [URL] = []) {
        self.webView = webView
        self.navigationHintURLs = navigationHintURLs
    }
}

