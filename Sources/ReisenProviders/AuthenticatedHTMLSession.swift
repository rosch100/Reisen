import Foundation

public enum AuthenticatedSessionError: Error, Sendable {
    case notEstablished
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
        isLoginHTML: (String) -> Bool
    ) throws -> String {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        if AuthenticatedSessionGuard.isUnauthorizedHTTP(status) {
            throw AuthenticatedSessionError.notEstablished
        }
        if let finalURL = response.url?.absoluteString,
           AuthPageURLHeuristic.looksLikeLoginPage(finalURL) {
            throw AuthenticatedSessionError.notEstablished
        }
        let html = try AuthenticatedTextDecode.utf8Text(data: data, response: response)
        if isLoginHTML(html) {
            throw AuthenticatedSessionError.notEstablished
        }
        return html
    }
}
