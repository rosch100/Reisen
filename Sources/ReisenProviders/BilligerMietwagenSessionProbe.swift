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

    /// Session-Cookies mit nicht-leerem Wert (SPA-`POST session.php`).
    public static func sessionCookiePresence(
        in cookies: [(name: String, hasValue: Bool)]
    ) -> Set<String> {
        Set(
            cookies.compactMap { cookie in
                guard BilligerMietwagenAuthConstants.sessionCookieNames.contains(cookie.name),
                      cookie.hasValue else { return nil }
                return cookie.name
            }
        )
    }

    /// Re-Probe, wenn nicht-leere Session-Cookies erscheinen oder verschwinden.
    public static func shouldReprobeAfterCookieChange(
        previousPresence: Set<String>,
        currentCookies: [(name: String, hasValue: Bool)]
    ) -> (shouldReprobe: Bool, newPresence: Set<String>) {
        let newPresence = sessionCookiePresence(in: currentCookies)
        return (newPresence != previousPresence, newPresence)
    }

    /// GET `session.php` mit Probe-Referer und Login-Auswertung (SSOT für Navigation + Session-UI).
    public static func fetchIsLoggedIn(
        using webView: WKWebView,
        timeoutSeconds: TimeInterval = 20
    ) async throws -> Bool? {
        let text = try await webView.fetchAuthenticatedText(
            url: BilligerMietwagenAuthConstants.sessionURL,
            accept: "application/json",
            referer: BilligerMietwagenAuthConstants.sessionProbeReferer,
            headers: BilligerMietwagenAuthConstants.sessionBrowserHeaders,
            timeoutSeconds: timeoutSeconds
        )
        return isLoggedIn(fromSessionJSON: text)
    }
}
