/// Login-HTML erkennen, wenn authentifizierter Seiteninhalt nicht ausreicht.
public enum AuthPageHTMLHeuristic {
    private static let passwordFieldMarker = "type=\"password\""
    private static let check24 = Profile(
        authenticated: ["\"activities\"", "activities.html"],
        required: ["user/login", passwordFieldMarker]
    )
    private static let opodo = Profile(
        authenticated: ["travel/secure"],
        required: [passwordFieldMarker]
    )

    public static func check24LooksLikeLoginHTML(_ html: String) -> Bool {
        matches(html, profile: check24)
    }

    public static func opodoLooksLikeLoginHTML(_ html: String) -> Bool {
        matches(html, profile: opodo)
    }

    private static func matches(_ html: String, profile: Profile) -> Bool {
        let lower = html.lowercased()
        if containsAny(lower, profile.authenticated) {
            return false
        }
        return containsAll(lower, profile.required)
    }

    private static func containsAny(_ haystack: String, _ markers: [String]) -> Bool {
        markers.contains { haystack.contains($0.lowercased()) }
    }

    private static func containsAll(_ haystack: String, _ markers: [String]) -> Bool {
        markers.allSatisfy { haystack.contains($0.lowercased()) }
    }

    private struct Profile {
        let authenticated: [String]
        let required: [String]
    }
}
