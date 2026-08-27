import Foundation
import WebKit
import ReisenDomain
import ReisenProviders

/// WebView-Interface für Booking.com-spezifische Fetch-/JS-Operationen.
/// Ziel: Hotspots in `BookingComTravelProvider` ohne echtes `WKWebView` testbar machen.
internal protocol BookingComWebView: NavigationWebView {
    func evaluateJavaScriptStringAsync(_ javaScript: String) async throws -> String?
    func fetchInPageText(
        url: URL,
        method: String,
        headers: [String: String],
        body: Data?
    ) async throws -> String

    func fetchAuthenticatedText(
        url: URL,
        method: String,
        accept: String,
        referer: String?,
        contentType: String?,
        body: Data?,
        headers: [String: String]
    ) async throws -> String
}

extension WKWebView: BookingComWebView {}

/// Session-Interface für `BookingComWebView`.
///
/// Main-Actor-isoliert, damit die `WebViewProviderSession`-Conformance zu `BookingComWebViewSession`
/// keine `[ConformanceIsolation]`-Fehler in Swift 6.2+ auslöst.
@MainActor
internal protocol BookingComWebViewSession: ProviderSession {
    var bookingComWebView: BookingComWebView { get }
}

extension WebViewProviderSession: BookingComWebViewSession {
    var bookingComWebView: BookingComWebView { webView }
}
