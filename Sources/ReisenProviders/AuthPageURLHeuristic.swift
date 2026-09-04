import Foundation

/// SSOT for provider web auth / account URL classification.
public enum AuthPageURLHeuristic {
    public static func looksLikeLoginPage(_ absoluteURL: String) -> Bool {
        AuthPageURLHaystack.containsAnyMarker(
            AuthPageURLHaystack.classificationHaystack(for: absoluteURL),
            AuthPageURLMarkers.login
        )
    }

    public static func looksLikeOneTimeCodeChallenge(_ absoluteURL: String) -> Bool {
        AuthPageURLHaystack.containsAnyMarker(
            AuthPageURLHaystack.classificationHaystack(for: absoluteURL),
            AuthPageURLMarkers.oneTimeCode
        )
    }

    public static func looksLikeAccountPage(_ absoluteURL: String) -> Bool {
        if AuthIdentityProviderHost.matches(urlAbsoluteString: absoluteURL) {
            return false
        }
        return AuthPageURLHaystack.containsAnyMarker(
            AuthPageURLHaystack.classificationHaystack(for: absoluteURL),
            AuthPageURLMarkers.account
        )
    }

    /// Account-URL ohne Login-Marker (Session-Heuristik „fertig“ / Probe-Skip).
    public static func looksLikeAccountPageWithoutLogin(_ absoluteURL: String) -> Bool {
        looksLikeAccountPage(absoluteURL) && !looksLikeLoginPage(absoluteURL)
    }

    /// Prefer applying OTP AutoFill whenever navigation may show an auth challenge.
    public static func shouldApplyOneTimeCodeAutofill(_ absoluteURL: String) -> Bool {
        if AuthIdentityProviderHost.matches(urlAbsoluteString: absoluteURL) {
            return false
        }
        return looksLikeLoginPage(absoluteURL) || looksLikeOneTimeCodeChallenge(absoluteURL)
    }

    /// Keychain password autofill only on non-IdP pages whose host matches the provider allowlist.
    public static func shouldApplyPasswordAutofill(
        _ absoluteURL: String,
        allowedServerHosts: [String]
    ) -> Bool {
        if AuthIdentityProviderHost.matches(urlAbsoluteString: absoluteURL) {
            return false
        }
        guard looksLikeLoginPage(absoluteURL) else { return false }
        guard let host = URL(string: absoluteURL)?.host, !host.isEmpty else { return false }
        let hosts = allowedServerHosts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        guard !hosts.isEmpty else { return false }
        return hosts.contains { KeychainHostMatching.server(host, matches: $0) }
    }
}
