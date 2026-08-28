import Foundation

/// GetYourGuide locale paths: Login-UI regional, Sync kanonisch EN.
enum GetYourGuideWebConstants {
    static let displayName = "GetYourGuide"
    static let origin = "https://www.getyourguide.com"
    private static let wwwPrefix = "www."
    static let bookingsPath = "customer-bookings"
    /// Login-WebView: passwordless OTP auf `/login` (HAR 2026-08-28), next= regionale Buchungsliste.
    static let loginLocalePath = "de-de"
    /// Unsichtbarer Sync: kanonische EN-Locale.
    static let syncLocalePath = "en-us"

    /// Apex-Host für Keychain und Same-Origin-Checks, abgeleitet von `origin`.
    static var cookieHost: String {
        guard let host = URL(string: origin)?.host?.lowercased() else {
            preconditionFailure("GYG origin ohne Host")
        }
        if host.hasPrefix(wwwPrefix) {
            return String(host.dropFirst(wwwPrefix.count))
        }
        return host
    }

    static var loginURL: URL {
        pageURL("/login?next=/\(loginLocalePath)/\(bookingsPath)/")
    }

    static var catalogSyncURL: URL {
        pageURL("/\(syncLocalePath)/\(bookingsPath)/")
    }

    static func bookingURL(hash: String) -> String {
        page("/\(syncLocalePath)/booking/\(hash)")
    }

    static func syncBookingURL(from externalUrl: String) -> URL? {
        guard var components = URLComponents(string: externalUrl),
              let host = components.host,
              isOwnHost(host)
        else {
            return nil
        }
        let path = components.path.isEmpty ? "/" : components.path
        if let match = path.wholeMatch(of: /^\/([a-z]{2}-[a-z]{2})(\/.*)?$/) {
            let suffix = match.2.map(String.init) ?? ""
            components.path = "/\(syncLocalePath)\(suffix)"
        } else if path == "/" {
            components.path = "/\(syncLocalePath)/"
        } else {
            components.path = "/\(syncLocalePath)\(path)"
        }
        return components.url
    }

    private static func isOwnHost(_ host: String) -> Bool {
        let h = host.lowercased()
        let apex = cookieHost
        return h == apex || h.hasSuffix("." + apex)
    }

    private static func page(_ path: String) -> String {
        origin + path
    }

    private static func pageURL(_ path: String) -> URL {
        guard let url = URL(string: page(path)) else {
            preconditionFailure("Ungültige GYG-URL: \(path)")
        }
        return url
    }
}
