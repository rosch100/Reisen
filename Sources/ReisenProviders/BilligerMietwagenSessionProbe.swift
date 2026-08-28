import Foundation
import WebKit

/// Session prüfen, wenn die URL-Heuristik unklar ist (z. B. Homepage nach Passwort-Login laut HAR).
public enum BilligerMietwagenSessionProbe {
    public static func applies(to url: URL) -> Bool {
        guard let host = url.host else { return false }
        return BilligerMietwagenAuthConstants.isPortalHost(host)
    }

    public static func isLoggedIn(fromSessionJSON text: String) -> Bool? {
        BilligerMietwagenAuthConstants.hasSessionTokens(inSessionJSON: text)
    }

    /// GET `session.php` mit Probe-Referer und Login-Auswertung (SSOT für Navigation + Session-UI).
    public static func fetchIsLoggedIn(using webView: WKWebView) async throws -> Bool? {
        let text = try await webView.fetchAuthenticatedText(
            url: BilligerMietwagenAuthConstants.sessionURL,
            accept: "application/json",
            referer: BilligerMietwagenAuthConstants.sessionProbeReferer
        )
        return isLoggedIn(fromSessionJSON: text)
    }
}
