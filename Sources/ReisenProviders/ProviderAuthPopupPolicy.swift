import Foundation

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

    public static func createAction(
        requestURL: URL?,
        allows: (URL) -> Bool
    ) -> CreateAction {
        guard let requestURL else { return .block }
        guard allows(requestURL) else { return .block }
        return .presentChild
    }

    /// Nach IdP-Login: Kind schließen, wenn die Navigation zurück auf die
    /// Provider-Site (gleiche registrierbare Domain) gelandet ist.
    public static func shouldDismissChildAfterLoad(
        childURL: URL,
        parentURL: URL?,
        sawIdentityProvider: Bool
    ) -> Bool {
        guard sawIdentityProvider else { return false }
        guard !AuthIdentityProviderHost.matches(urlAbsoluteString: childURL.absoluteString) else {
            return false
        }
        guard let parentHost = parentURL?.host else { return false }
        guard let childHost = childURL.host else { return false }
        return sharesRegistrableDomain(childHost, parentHost)
    }

    public static func noteIdentityProviderSighting(
        currentURL: URL,
        alreadySawIdentityProvider: Bool
    ) -> Bool {
        if alreadySawIdentityProvider { return true }
        return AuthIdentityProviderHost.matches(urlAbsoluteString: currentURL.absoluteString)
    }

    static func sharesRegistrableDomain(_ hostA: String, _ hostB: String) -> Bool {
        registrableDomain(hostA) == registrableDomain(hostB)
    }

    private static func registrableDomain(_ host: String) -> String {
        let parts = host.lowercased().split(separator: ".")
        guard parts.count >= 2 else { return host.lowercased() }
        return parts.suffix(2).joined(separator: ".")
    }
}
