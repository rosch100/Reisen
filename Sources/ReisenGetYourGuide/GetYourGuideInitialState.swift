import Foundation

/// Extrahiert `window.__INITIAL_STATE__ = {…}` aus HTML (Brace-Scan, kein naives Regex bis Dateiende).
public enum GetYourGuideInitialState {
    static let marker = "__INITIAL_STATE__"

    /// Liefert das JSON-Objekt hinter `__INITIAL_STATE__`, oder `nil` wenn nicht gefunden.
    public static func extractJSONObject(fromHTML html: String) -> String? {
        guard let markerRange = html.range(of: marker) else { return nil }
        let afterMarker = html[markerRange.upperBound...]
        guard let openBrace = afterMarker.firstIndex(of: "{") else { return nil }
        guard let closed = scanBalancedObject(in: html, openBrace: openBrace) else { return nil }
        return String(html[openBrace...closed])
    }

    public static func looksLikeCloudflareChallenge(_ html: String) -> Bool {
        containsAny(html.lowercased(), challengeMarkers)
    }

    /// Passwordless OTP (HAR): kein Passwort-Feld. Login-URL prüft `AuthenticatedHTMLSession`.
    /// Session: Keys `myBookings` oder `bookingSummary` in `__INITIAL_STATE__` (nicht Asset-Substrings).
    /// `__INITIAL_STATE__` ohne diese Keys → Login.
    public static func looksLikeLoginHTML(_ html: String) -> Bool {
        guard let json = extractJSONObject(fromHTML: html) else {
            return containsAny(html.lowercased(), passwordlessLoginMarkers)
        }
        return !hasSessionKeys(in: json)
    }

    private static let challengeMarkers = [
        "cdn-cgi/challenge-platform",
        "cf-browser-verification",
        "cf-turnstile",
        "challenge-stage",
    ]
    private static let sessionJSONKeys: Set<String> = ["myBookings", "bookingSummary"]
    private static let passwordlessLoginMarkers = [
        "otp-centric-login",
        "/auth/passwordless",
        "verification-code-field",
    ]

    private static func hasSessionKeys(in json: String) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) else {
            return false
        }
        return hasSessionKeys(inJSONValue: object)
    }

    private static func hasSessionKeys(inJSONValue value: Any) -> Bool {
        switch value {
        case let dict as [String: Any]:
            if sessionJSONKeys.contains(where: { dict[$0] != nil }) {
                return true
            }
            return dict.values.contains { hasSessionKeys(inJSONValue: $0) }
        case let array as [Any]:
            return array.contains { hasSessionKeys(inJSONValue: $0) }
        default:
            return false
        }
    }

    private static func containsAny(_ haystack: String, _ markers: [String]) -> Bool {
        markers.contains { haystack.contains($0) }
    }

    /// Brace-Scan mit String-/Escape-Awareness.
    private static func scanBalancedObject(in text: String, openBrace: String.Index) -> String.Index? {
        var depth = 0
        var inString = false
        var isEscaped = false
        var index = openBrace

        while index < text.endIndex {
            let ch = text[index]

            if inString {
                if isEscaped {
                    isEscaped = false
                } else if ch == "\\" {
                    isEscaped = true
                } else if ch == "\"" {
                    inString = false
                }
            } else {
                switch ch {
                case "\"":
                    inString = true
                case "{":
                    depth += 1
                case "}":
                    depth -= 1
                    if depth == 0 {
                        return index
                    }
                default:
                    break
                }
            }

            index = text.index(after: index)
        }

        return nil
    }
}
