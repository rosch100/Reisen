import Foundation

public enum HTTPCookieHostMatching {
    /// RFC-konformes Cookie-Domain-Matching (kein Suffix ohne Dot-Grenze).
    public static func matches(_ cookie: HTTPCookie, url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let domain = cookie.domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !domain.isEmpty else { return false }
        return host == domain || host.hasSuffix("." + domain)
    }
}
