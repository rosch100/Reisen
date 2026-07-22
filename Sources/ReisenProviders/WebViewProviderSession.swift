import WebKit

/// Generic provider session that wraps the embedded `WKWebView`.
@MainActor
public final class WebViewProviderSession: ProviderSession {
    public let webView: WKWebView

    public init(webView: WKWebView) {
        self.webView = webView
    }
}

