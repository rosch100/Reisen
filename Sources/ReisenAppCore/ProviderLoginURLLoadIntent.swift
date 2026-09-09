import Foundation

/// Entscheidet, ob die Sync-/Probe-WebView die Login-URL laden soll.
/// SSOT gegen Coordinator-Remount-Churn und First-Enable-Reparent mit leerem `WKWebView`.
public enum ProviderLoginURLLoadIntent: Sendable {
    public enum Decision: Equatable, Sendable {
        case skip
        /// Coordinator an Hub-Intent anbinden, Navigation nicht anfassen (Remount mit Inhalt).
        case markLoaded
        case load(URL)
    }

    /// - Parameters:
    ///   - loginURL: gewünschte Login-URL des Providers
    ///   - allowsEmbed: Display-Policy erlaubt Einbindung
    ///   - coordinatorLoadedURL: zuletzt vom aktuellen Representable-Coordinator markierte URL
    ///   - hubRequestedURL: Hub-SSOT der zuletzt angeforderten Login-URL (überlebt Remount)
    ///   - webViewURLString: `WKWebView.url?.absoluteString` (nil/`about:blank` = leer)
    ///   - isLoading: `WKWebView.isLoading` — unterscheidet in-flight Navigation von Reparent-Leere
    public static func decide(
        loginURL: URL?,
        allowsEmbed: Bool,
        coordinatorLoadedURL: URL?,
        hubRequestedURL: URL?,
        webViewURLString: String?,
        isLoading: Bool
    ) -> Decision {
        guard allowsEmbed, let loginURL else { return .skip }

        let pageEmpty = isBlankWebViewURL(webViewURLString)
        let pageAtLogin = webViewURLString == loginURL.absoluteString

        if coordinatorLoadedURL == loginURL {
            // make→update: Navigation läuft schon, URL noch leer — kein Doppel-load.
            if isLoading { return .skip }
            // Reparent-Race: Intent markiert, Seite leer und idle → nachladen.
            return pageEmpty ? .load(loginURL) : .skip
        }

        if hubRequestedURL == loginURL {
            if isLoading { return .markLoaded }
            // Remount mit neuem Coordinator: bei Inhalt (Login oder OAuth) nicht neu navigieren.
            return pageEmpty ? .load(loginURL) : .markLoaded
        }

        if pageAtLogin {
            return .markLoaded
        }
        return .load(loginURL)
    }

    public static func isBlankWebViewURL(_ urlString: String?) -> Bool {
        guard let urlString, !urlString.isEmpty else { return true }
        return urlString == "about:blank"
    }
}
