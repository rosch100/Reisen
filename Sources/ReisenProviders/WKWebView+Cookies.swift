import Foundation
import WebKit

extension WKWebView {
    /// Reads all cookies from the WebView's website data store.
    public func allHTTPCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }
}
