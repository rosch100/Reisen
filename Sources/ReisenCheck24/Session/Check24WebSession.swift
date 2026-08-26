import Foundation
import WebKit
import ReisenProviders

/// WKWebView-backed session for Check24.
@MainActor
public final class Check24WebSession: ProviderSession {
    public let webView: WKWebView

    public init(webView: WKWebView) {
        self.webView = webView
    }
}
