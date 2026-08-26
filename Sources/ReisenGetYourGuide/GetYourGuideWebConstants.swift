import Foundation

/// GetYourGuide locale paths: Login-UI regional, Sync kanonisch EN.
enum GetYourGuideWebConstants {
    static let origin = "https://www.getyourguide.com"
    /// Login-WebView: bekannte regionale Oberfläche.
    static let loginLocalePath = "de-de"
    /// Unsichtbarer Sync: kanonische EN-Locale.
    static let syncLocalePath = "en-us"

    static var loginURL: URL {
        URL(string: "\(origin)/\(loginLocalePath)/customer-bookings/")!
    }

    static var catalogSyncURL: URL {
        URL(string: "\(origin)/\(syncLocalePath)/customer-bookings/")!
    }

    static func bookingURL(hash: String) -> String {
        "\(origin)/\(syncLocalePath)/booking/\(hash)"
    }

    static func syncBookingURL(from externalUrl: String) -> URL? {
        guard var components = URLComponents(string: externalUrl),
              let host = components.host?.lowercased(),
              host == "getyourguide.com" || host.hasSuffix(".getyourguide.com")
        else {
            return nil
        }
        let path = components.path.isEmpty ? "/" : components.path
        let localePattern = #"^/([a-z]{2}-[a-z]{2})(/.*)?$"#
        if let regex = try? NSRegularExpression(pattern: localePattern, options: []),
           let match = regex.firstMatch(
               in: path,
               options: [],
               range: NSRange(path.startIndex..<path.endIndex, in: path)
           ) {
            let suffix: String
            if match.range(at: 2).location != NSNotFound,
               let suffixRange = Range(match.range(at: 2), in: path) {
                suffix = String(path[suffixRange])
            } else {
                suffix = ""
            }
            components.path = "/\(syncLocalePath)\(suffix)"
        } else if path == "/" {
            components.path = "/\(syncLocalePath)/"
        } else {
            components.path = "/\(syncLocalePath)\(path)"
        }
        return components.url
    }
}
