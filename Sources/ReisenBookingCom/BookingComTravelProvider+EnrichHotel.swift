import Foundation
import ReisenProviders

@MainActor
extension BookingComTravelProvider {
    /// HAR: Fee-Schedule nur auf `confirmation.html` (nicht locale `confirmation.de.html`); Session/WAF via WebView.
    func loadHotelConfirmationHTML(using webView: BookingComWebView, url: URL) async throws -> String {
        do {
            let text = try await webView.fetchInPageText(
                url: url,
                method: "GET",
                headers: [
                    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                    "Referer": Self.myTripsURL.absoluteString,
                ],
                body: nil
            )
            if Self.looksLikeHotelConfirmation(text) {
                return text
            }
        } catch {
            // Navigation-Fallback unten.
        }

        try await NavigationAwaiter().load(url, in: webView)
        try? await Task.sleep(nanoseconds: 600_000_000)
        if let snapshot = try await webView.evaluateJavaScriptStringAsync("document.documentElement.outerHTML"),
           Self.looksLikeHotelConfirmation(snapshot) {
            return snapshot
        }

        return try await webView.fetchAuthenticatedText(
            url: url,
            method: "GET",
            accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            referer: Self.myTripsURL.absoluteString,
            contentType: nil,
            body: nil,
            headers: [:]
        )
    }

    static func looksLikeHotelConfirmation(_ html: String) -> Bool {
        let lower = html.lowercased()
        return lower.contains("e2e-cancellation-breakdown")
            || lower.contains("e2e-conf-cancellation-cost")
            || lower.contains("stornierungsgebühren")
            || lower.contains("conf-free-cancellation")
            || lower.contains("cancellation_fee")
    }
}
