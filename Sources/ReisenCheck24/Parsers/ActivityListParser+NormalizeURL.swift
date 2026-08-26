import Foundation

extension ActivityListParser {
    /// Mobile/UL-Links auf stabile Desktop-Buchungs-URLs normalisieren.
    func normalizeBookingDetailURL(_ raw: String) -> String {
        var urlString = raw
        if let q = urlString.firstIndex(of: "?") {
            urlString = String(urlString[..<q])
        }

        if let uuid = extractUUID(from: urlString),
           urlString.lowercased().contains("hotel"),
           urlString.lowercased().contains("buchung") {
            return "https://hotel.check24.de/kundenbereich/buchung/\(uuid)"
        }

        return stripMobileHotelPrefix(urlString)
    }
}
