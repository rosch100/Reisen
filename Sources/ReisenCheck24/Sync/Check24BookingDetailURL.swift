import Foundation
import ReisenDomain

/// SSOT: Check24-Buchungsdetail-Hosts und -Pfade (Live-Audit 2026-08-28).
enum Check24BookingDetailURL {
    private static let kundenbereichBuchungSegments = ["kundenbereich", "buchung"]
    private static let carRentalBookingPathPrefix = "/ul/booking/"
    private static let carRentalShortPathPrefix = "kb"

    static func isHotelStayDetail(_ url: URL) -> Bool {
        isKundenbereichBuchung(url, hosts: ["hotel.check24.de", "ferienwohnung.check24.de"])
    }

    static func isFlightOrFerryDetail(_ url: URL) -> Bool {
        isKundenbereichBuchung(url, hosts: ["flug.check24.de", "ferry.check24.de"])
    }

    /// Mietwagen-Detail: Katalog `/ul/booking/…` oder Redirect `/kb/{id}`.
    static func isCarRentalDetail(_ url: URL) -> Bool {
        guard isExactHost(url, Check24CarRentalJumpin.host) else { return false }
        let path = url.path.lowercased()
        if path.hasPrefix(carRentalBookingPathPrefix) { return true }
        let parts = path.split(separator: "/").map(String.init)
        return parts.count == 2
            && parts[0] == carRentalShortPathPrefix
            && !parts[1].isEmpty
    }

    /// Gleiche Buchung trotz Redirect (`…/foreign/:id` ↔ `/kb/:id`). Exaktes Path-Segment, kein Substring.
    static func isSameCarRentalBooking(_ lhs: URL, _ rhs: URL) -> Bool {
        if lhs.absoluteString == rhs.absoluteString { return true }
        guard isCarRentalDetail(lhs), isCarRentalDetail(rhs) else { return false }
        guard let leftID = bookingPathID(lhs), let rightID = bookingPathID(rhs) else { return false }
        return leftID.caseInsensitiveCompare(rightID) == .orderedSame
    }

    private static func isKundenbereichBuchung(_ url: URL, hosts: [String]) -> Bool {
        guard isExactHost(url, anyOf: hosts) else { return false }
        return hasConsecutivePathSegments(url, kundenbereichBuchungSegments)
    }

    private static func isExactHost(_ url: URL, _ host: String) -> Bool {
        isExactHost(url, anyOf: [host])
    }

    private static func isExactHost(_ url: URL, anyOf hosts: [String]) -> Bool {
        let host = (url.host ?? "").lowercased()
        return hosts.contains { host == $0.lowercased() }
    }

    /// Path enthält die Segmente als zusammenhängende Folge (z. B. `/ul/kundenbereich/buchung/…`).
    private static func hasConsecutivePathSegments(_ url: URL, _ segments: [String]) -> Bool {
        let parts = url.path.lowercased().split(separator: "/").map(String.init)
        let needle = segments.map { $0.lowercased() }
        guard !needle.isEmpty, parts.count >= needle.count else { return false }
        for start in 0...(parts.count - needle.count) {
            if Array(parts[start..<(start + needle.count)]) == needle {
                return true
            }
        }
        return false
    }

    private static func bookingPathID(_ url: URL) -> String? {
        NonEmpty.string(url.path.split(separator: "/").last.map(String.init))
    }
}
