import Foundation
import ReisenDomain

extension ActivityListParser {
    /// Mobile/UL-Links auf stabile Desktop-Buchungs-URLs normalisieren.
    func normalizeBookingDetailURL(_ raw: String, bookingType: BookingType = .other) -> String {
        var urlString = raw
        if let q = urlString.firstIndex(of: "?") {
            urlString = String(urlString[..<q])
        }

        if let uuid = extractUUID(from: urlString),
           urlString.lowercased().contains("buchung") {
            let host = Check24KundenbereichHost.host(fromDetailURL: urlString)
                ?? Check24KundenbereichHost.host(for: bookingType)
            return "https://\(host)/kundenbereich/buchung/\(uuid)"
        }

        return stripMobileHotelPrefix(urlString)
    }
}
