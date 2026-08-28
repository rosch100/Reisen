import Foundation

/// SSOT: Mietwagen-Host sowie Jumpin-Pfad/Query (Detail-URL, Catalog-Actions, Gap-Deep-Link).
enum Check24CarRentalJumpin {
    static let host = "mietwagen.check24.de"
    static let path = "/ul/jumpin"
    static let sourceQuery = "source"
    static let sourceGap = "reisen_gap"
    static let depName = "dep_destination_name"
    static let destName = "dest_destination_name"
    static let depTitle = "dep_destination_title"
    static let destTitle = "dest_destination_title"

    static func searchURL(pickup: String, dropoff: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = [
            URLQueryItem(name: sourceQuery, value: sourceGap),
            URLQueryItem(name: depName, value: pickup),
            URLQueryItem(name: destName, value: dropoff),
            URLQueryItem(name: depTitle, value: pickup),
            URLQueryItem(name: destTitle, value: dropoff),
        ]
        return components.url
    }
}
