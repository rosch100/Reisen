import Foundation
import WebKit

import ReisenDomain

@MainActor
public extension TravelProvider {
    func makeSyncSession(
        webView: WKWebView,
        navigationHintURLs: [URL] = []
    ) -> any ProviderSession {
        WebViewProviderSession(
            webView: webView,
            navigationHintURLs: navigationHintURLs
        )
    }
}
