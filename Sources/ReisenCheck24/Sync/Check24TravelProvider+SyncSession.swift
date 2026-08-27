import Foundation
import WebKit

import ReisenDomain
import ReisenProviders

extension Check24TravelProvider {
    public func makeSyncSession(
        webView: WKWebView,
        navigationHintURLs: [URL] = []
    ) -> any ProviderSession {
        Check24WebSession(webView: webView)
    }
}
