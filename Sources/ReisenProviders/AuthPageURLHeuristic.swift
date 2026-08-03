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
        AuthPageURLHaystack.containsAnyMarker(
            AuthPageURLHaystack.classificationHaystack(for: absoluteURL),
            AuthPageURLMarkers.account
        )
    }

    /// Prefer applying OTP AutoFill whenever navigation may show an auth challenge.
    public static func shouldApplyOneTimeCodeAutofill(_ absoluteURL: String) -> Bool {
        looksLikeLoginPage(absoluteURL) || looksLikeOneTimeCodeChallenge(absoluteURL)
    }
}
