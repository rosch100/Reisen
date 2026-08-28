import Foundation

/// SSOT for Opodo website URLs (homepage, My-Trips, trip-detail hash).
public enum OpodoWeb {
    public static let origin = "https://www.opodo.de"
    public static let homepageURLString = origin + "/"
    public static let secureAreaPathPrefix = "/travel/secure"
    public static let secureAreaURLString = origin + secureAreaPathPrefix + "/"
    public static let tripDetailsTokenMarker = "#tripdetails/td="

    public static var homepageURL: URL { URL(string: homepageURLString)! }
    public static var secureAreaURL: URL { URL(string: secureAreaURLString)! }

    /// HAR: `getTripByToken` uses Referer without trailing slash.
    public static let secureAreaRefererWithoutTrailingSlash = origin + secureAreaPathPrefix

    public static func tripDetailsURL(token: String) -> String {
        "\(secureAreaURLString)\(tripDetailsTokenMarker)\(token)"
    }

    public static func tdToken(fromExternalURL urlString: String) -> String? {
        guard let marker = urlString.range(of: tripDetailsTokenMarker) else { return nil }
        let raw = String(urlString[marker.upperBound...])
        let token = raw.split(whereSeparator: { $0 == "/" || $0 == "?" || $0 == "&" || $0 == "#" }).first
        guard let token, !token.isEmpty else { return nil }
        return String(token)
    }
}
