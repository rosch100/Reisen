import Foundation

public enum AuthenticatedSessionError: Error, Sendable {
    case notEstablished
    case challenge
}

public enum AuthenticatedSessionGuard {
    public static func isUnauthorizedHTTP(_ status: Int) -> Bool {
        status == 401 || status == 403
    }

    public static func isUnauthorized(_ error: AuthenticatedFetchError) -> Bool {
        guard case .httpStatus(let code) = error else { return false }
        return isUnauthorizedHTTP(code)
    }
}

public enum AuthenticatedHTMLSession {
    public static func validatedUTF8HTML(
        data: Data,
        response: URLResponse,
        isLoginHTML: (String) -> Bool,
        isChallengeHTML: ((String) -> Bool)? = nil
    ) throws -> String {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        if AuthenticatedSessionGuard.isUnauthorizedHTTP(status) {
            try throwIfChallenge(AuthenticatedTextDecode.utf8String(data), isChallengeHTML)
            throw AuthenticatedSessionError.notEstablished
        }
        let html = try AuthenticatedTextDecode.utf8Text(data: data, response: response)
        try throwIfChallenge(html, isChallengeHTML)
        try throwIfNotEstablished(response: response, html: html, isLoginHTML: isLoginHTML)
        return html
    }

    private static func throwIfNotEstablished(
        response: URLResponse,
        html: String,
        isLoginHTML: (String) -> Bool
    ) throws {
        let loginURL = response.url.map { AuthPageURLHeuristic.looksLikeLoginPage($0.absoluteString) } ?? false
        if loginURL || isLoginHTML(html) {
            throw AuthenticatedSessionError.notEstablished
        }
    }

    private static func throwIfChallenge(_ html: String?, _ isChallengeHTML: ((String) -> Bool)?) throws {
        guard let html, let isChallengeHTML, isChallengeHTML(html) else { return }
        throw AuthenticatedSessionError.challenge
    }
}
