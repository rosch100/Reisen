import Foundation

/// SSOT for provider web auth / account URL classification.
public enum AuthPageURLHeuristic {
    public static func looksLikeLoginPage(_ absoluteURL: String) -> Bool {
        containsAnyMarker(
            classificationHaystack(for: absoluteURL),
            [
                "login",
                "anmelden",
                "signin",
                "sign-in",
                "sign_in",
                "identity",
                "authenticate",
                "auth/",
            ]
        )
    }

    public static func looksLikeOneTimeCodeChallenge(_ absoluteURL: String) -> Bool {
        containsAnyMarker(
            classificationHaystack(for: absoluteURL),
            [
                "otp",
                "mfa",
                "2fa",
                "two-factor",
                "twofactor",
                "tan",
                "sicherheitscode",
                "verification-code",
                "verify-code",
                "verifycode",
                "auth-code",
                "authcode",
                "einmalcode",
                "one-time-code",
                "onetimecode",
                "one_time_code",
            ]
        )
    }

    public static func looksLikeAccountPage(_ absoluteURL: String) -> Bool {
        containsAnyMarker(
            classificationHaystack(for: absoluteURL),
            [
                "airbnb",
                "account",
                "activitylist",
                "activities",
                "kundenbereich",
                "mytrips",
                "my-bookings",
                "my-trips",
                "travel-center",
                "bookings",
                "/trips",
                // Opodo My Trips / Secure-Area (nach Login) — kein Login-Einstieg.
                "/travel/secure",
            ]
        )
    }

    /// Prefer applying OTP AutoFill whenever navigation may show an auth challenge.
    /// Callers that want maximum coverage should apply `OneTimeCodeAutofill` on every navigation;
    /// this helper remains for optional gating and tests.
    public static func shouldApplyOneTimeCodeAutofill(_ absoluteURL: String) -> Bool {
        looksLikeLoginPage(absoluteURL) || looksLikeOneTimeCodeChallenge(absoluteURL)
    }

    /// Host + Path only — Query/Fragment oft mit SSO-`callback`/`context_ref` auf Login-URLs,
    /// die eine bereits eingeloggte Account-Seite sonst fälschlich als Login markieren.
    private static func classificationHaystack(for absoluteURL: String) -> String {
        let lowered = absoluteURL.lowercased()
        guard let components = URLComponents(string: absoluteURL) else {
            return lowered
        }
        let host = (components.host ?? "").lowercased()
        let path = components.path.lowercased()
        if host.isEmpty && path.isEmpty {
            return lowered
        }
        return host + path
    }

    private static func containsAnyMarker(_ haystack: String, _ markers: [String]) -> Bool {
        markers.contains { containsMarker(haystack, $0) }
    }

    private static func containsMarker(_ haystack: String, _ marker: String) -> Bool {
        var searchStart = haystack.startIndex
        while searchStart < haystack.endIndex,
              let range = haystack.range(of: marker, range: searchStart..<haystack.endIndex) {
            if marker == "account" {
                // Host `accounts.*` enthält "account" als Präfix von "accounts" — kein Account-Marker.
                let after = range.upperBound
                if after < haystack.endIndex, haystack[after] == "s" {
                    searchStart = after
                    continue
                }
            }
            return true
        }
        return false
    }
}
