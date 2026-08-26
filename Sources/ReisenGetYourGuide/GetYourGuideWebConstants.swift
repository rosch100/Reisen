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
        guard var components = URLComponents(string: externalUrl) else { return nil }
        let path = components.path
        let localePattern = #"^/([a-z]{2}-[a-z]{2})(/.*)?$"#
        guard let regex = try? NSRegularExpression(pattern: localePattern, options: []) else {
            return URL(string: externalUrl)
        }
        let range = NSRange(path.startIndex..<path.endIndex, in: path)
        guard let match = regex.firstMatch(in: path, options: [], range: range),
              let suffixRange = Range(match.range(at: 2), in: path)
        else {
            return URL(string: externalUrl)
        }
        let suffix = String(path[suffixRange])
        components.path = "/\(syncLocalePath)\(suffix)"
        return components.url
    }
}
