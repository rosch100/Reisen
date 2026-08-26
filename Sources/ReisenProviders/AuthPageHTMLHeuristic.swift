import Foundation

/// SSOT: Login-HTML erkennen, wenn URL-Heuristik und authentifizierter Seiteninhalt nicht ausreichen.
public enum AuthPageHTMLHeuristic {
    private static let check24AuthenticatedMarkers = ["\"activities\"", "activities.html"]
    private static let check24RequiredMarkers = ["user/login", "type=\"password\""]
    private static let opodoAuthenticatedMarkers = ["travel/secure"]
    private static let opodoRequiredMarkers = ["type=\"password\""]

    public static func looksLikeLoginPage(
        html: String,
        responseURL: URL? = nil,
        authenticatedContentMarkers: [String] = [],
        requiredHTMLMarkers: [String] = ["type=\"password\""]
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

    /// Nur HTML-Marker — URL-Prüfung erfolgt in `AuthenticatedHTMLSession`.
    public static func htmlLooksLikeLoginPage(
        html: String,
        authenticatedContentMarkers: [String],
        requiredHTMLMarkers: [String]
    ) -> Bool {
        let lower = html.lowercased()
        if authenticatedContentMarkers.contains(where: { lower.contains($0.lowercased()) }) {
            return false
        }
        return requiredHTMLMarkers.allSatisfy { lower.contains($0.lowercased()) }
    }

    public static func check24HTMLLooksLikeLogin(_ html: String) -> Bool {
        check24LooksLikeLoginHTML(html)
    }

    public static func opodoHTMLLooksLikeLogin(_ html: String) -> Bool {
        opodoLooksLikeLoginHTML(html)
    }

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
}
