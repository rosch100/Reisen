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

    /// Prefer applying OTP AutoFill whenever navigation may show an auth challenge.
    public static func shouldApplyOneTimeCodeAutofill(_ absoluteURL: String) -> Bool {
        if AuthIdentityProviderHost.matches(urlAbsoluteString: absoluteURL) {
            return false
        }
        return looksLikeLoginPage(absoluteURL) || looksLikeOneTimeCodeChallenge(absoluteURL)
    }

    /// Keychain password autofill only on non-IdP pages (Sign in with Apple/Google must stay untouched).
    public static func shouldApplyPasswordAutofill(_ absoluteURL: String) -> Bool {
        if AuthIdentityProviderHost.matches(urlAbsoluteString: absoluteURL) {
            return false
        }
        return looksLikeLoginPage(absoluteURL)
    }
}
