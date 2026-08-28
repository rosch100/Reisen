import Foundation

/// SSOT: Login-HTML erkennen, wenn URL-Heuristik und authentifizierter Seiteninhalt nicht ausreichen.
public enum AuthPageHTMLHeuristic {
    private static let passwordFieldMarker = "type=\"password\""
    private static let check24AuthenticatedMarkers = ["\"activities\"", "activities.html"]
    private static let check24RequiredMarkers = ["user/login", passwordFieldMarker]
    private static let opodoAuthenticatedMarkers = ["travel/secure"]
    private static let opodoRequiredMarkers = [passwordFieldMarker]

    public static func check24LooksLikeLoginHTML(_ html: String, responseURL: URL? = nil) -> Bool {
        looksLikeLoginPage(
            html: html,
            responseURL: responseURL,
            authenticatedContentMarkers: check24AuthenticatedMarkers,
            requiredHTMLMarkers: check24RequiredMarkers
        )
    }

    public static func opodoLooksLikeLoginHTML(_ html: String, responseURL: URL? = nil) -> Bool {
        looksLikeLoginPage(
            html: html,
            responseURL: responseURL,
            authenticatedContentMarkers: opodoAuthenticatedMarkers,
            requiredHTMLMarkers: opodoRequiredMarkers
        )
    }

    private static func looksLikeLoginPage(
        html: String,
        responseURL: URL?,
        authenticatedContentMarkers: [String],
        requiredHTMLMarkers: [String]
    ) -> Bool {
        if let responseURL {
            let absolute = responseURL.absoluteString
            if AuthPageURLHeuristic.looksLikeLoginPage(absolute) {
                return true
            }
            if AuthPageURLHeuristic.looksLikeAccountPage(absolute) {
                return false
            }
        }
        return htmlLooksLikeLoginPage(
            html: html,
            authenticatedContentMarkers: authenticatedContentMarkers,
            requiredHTMLMarkers: requiredHTMLMarkers
        )
    }

    /// Nur HTML-Marker. URL-Prüfung liegt in `looksLikeLoginPage`.
    private static func htmlLooksLikeLoginPage(
        html: String,
        authenticatedContentMarkers: [String],
        requiredHTMLMarkers: [String]
    ) -> Bool {
        let lower = html.lowercased()
        if containsAny(lower, authenticatedContentMarkers) {
            return false
        }
        return containsAll(lower, requiredHTMLMarkers)
    }

    private static func containsAny(_ haystack: String, _ markers: [String]) -> Bool {
        markers.contains { haystack.contains($0.lowercased()) }
    }

    private static func containsAll(_ haystack: String, _ markers: [String]) -> Bool {
        markers.allSatisfy { haystack.contains($0.lowercased()) }
    }
}
