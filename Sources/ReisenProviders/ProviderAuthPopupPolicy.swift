import Foundation
import ReisenDomain

/// Entscheidungslogik für `target=_blank` / SSO-Popups in Provider-WebViews.
///
/// OAuth-Flows (z. B. Sign in with Apple) brauchen ein echtes Kind-`WKWebView`
/// mit `window.opener`. Einladen in dieselbe WebView (`popup_reparented`) zerstört
/// den Opener — der Callback (z. B. `auth.getyourguide.com`) bleibt dann leer.
public enum ProviderAuthPopupPolicy: Sendable {
    public enum CreateAction: Equatable, Sendable {
        case block
        case presentChild
    }

    /// Diagnose-Event-Namen (macOS + iOS).
    public enum Event {
        public static let blocked = "popup_blocked"
        public static let presentFailed = "popup_present_failed"
        public static let presented = "popup_presented"
        public static let closed = "popup_closed"
        public static let completed = "popup_completed"
    }

    /// Diagnose-`reason`-Werte (macOS + iOS).
    public enum Reason {
        public static let childWebView = "child_webview"
        public static let webViewDidClose = "webview_did_close"
        public static let returnedToProviderSite = "returned_to_provider_site"
        public static let missingHost = "missing_host"
        public static let missingRequestURL = "missing_request_url"
        public static let navigationPolicy = "navigation_policy"
    }

    /// Wartet kurz, damit Callback-Seiten `window.opener` + `close` nutzen können.
    /// Parent danach nicht neu laden: OAuth (z. B. GYG) postMessage't an den Opener.
    public static let childDismissDelay: TimeInterval = 0.75

    public static func createAction(
        requestURL: URL?,
        allows: (URL) -> Bool
    ) -> CreateAction {
        guard let requestURL else { return .block }
        guard allows(requestURL) else { return .block }
        return .presentChild
    }

    public static func blockReason(requestURL: URL?) -> String {
        requestURL == nil ? Reason.missingRequestURL : Reason.navigationPolicy
    }

    /// `true`, wenn der gebundene Provider gewechselt hat (Caller soll Popup schließen).
    @discardableResult
    public static func bindProvider(
        _ next: ProviderID,
        previous: inout ProviderID?
    ) -> Bool {
        guard previous != next else { return false }
        previous = next
        return true
    }

    /// Nach IdP-Login: Kind schließen, wenn die Navigation zurück auf die
    /// Provider-Site (gleiche registrierbare Domain) gelandet ist.
    public static func shouldDismissChildAfterLoad(
        childURL: URL,
        parentURL: URL?,
        sawIdentityProvider: Bool
    ) -> Bool {
        guard sawIdentityProvider else { return false }
        guard let childHost = childURL.host else { return false }
        guard !AuthIdentityProviderHost.matches(childHost) else { return false }
        guard let parentHost = parentURL?.host else { return false }
        return sharesRegistrableDomain(childHost, parentHost)
    }

    public static func noteIdentityProviderSighting(
        currentURL: URL,
        alreadySawIdentityProvider: Bool
    ) -> Bool {
        if alreadySawIdentityProvider { return true }
        guard let host = currentURL.host else { return false }
        return AuthIdentityProviderHost.matches(host)
    }

    public static func initialIdentityProviderSighting(requestURL: URL?) -> Bool {
        guard let requestURL else { return false }
        return noteIdentityProviderSighting(
            currentURL: requestURL,
            alreadySawIdentityProvider: false
        )
    }

    static func sharesRegistrableDomain(_ hostA: String, _ hostB: String) -> Bool {
        registrableDomain(hostA) == registrableDomain(hostB)
    }

    /// eTLD+1-Näherung: bekannte Multi-Part-TLDs (z. B. `co.uk`) brauchen drei Labels.
    static func registrableDomain(_ host: String) -> String {
        let parts = host.lowercased().split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return host.lowercased() }
        if parts.count >= 3 {
            let lastTwo = parts.suffix(2).joined(separator: ".")
            if multiPartTLDs.contains(lastTwo) {
                return parts.suffix(3).joined(separator: ".")
            }
        }
        return parts.suffix(2).joined(separator: ".")
    }

    /// Häufige Multi-Part-Public-Suffixes (kein vollständiger PSL; erweitert bei Bedarf).
    private static let multiPartTLDs: Set<String> = [
        "co.uk", "org.uk", "ac.uk", "gov.uk", "me.uk",
        "com.au", "net.au", "org.au", "edu.au",
        "co.nz", "org.nz", "net.nz",
        "co.jp", "or.jp", "ne.jp",
        "com.br", "com.mx", "com.ar",
        "co.kr", "co.in", "com.sg", "com.hk", "com.tw",
    ]
}
