import Foundation
import ReisenDomain

/// SSOT: Check24-Buchungsdetail-Hosts und -Pfade (Live-Audit 2026-08-28).
enum Check24BookingDetailURL {
    private static let kundenbereichBuchungPath = "/kundenbereich/buchung/"
    private static let carRentalBookingPath = "/ul/booking/"
    private static let carRentalShortPathPrefix = "kb"

    static func isHotelStayDetail(_ url: URL) -> Bool {
        isKundenbereichBuchung(url, hosts: ["hotel.check24.de", "ferienwohnung.check24.de"])
    }

    static func isFlightOrFerryDetail(_ url: URL) -> Bool {
        isKundenbereichBuchung(url, hosts: ["flug.check24.de", "ferry.check24.de"])
    }

    /// Mietwagen-Detail: Katalog `/ul/booking/…` oder Redirect `/kb/{id}`.
    static func isCarRentalDetail(_ url: URL) -> Bool {
        guard host(url, containsAny: [Check24CarRentalJumpin.host]) else { return false }
        let path = url.path.lowercased()
        if path.contains(carRentalBookingPath) { return true }
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
        host(url, containsAny: hosts) && url.path.lowercased().contains(kundenbereichBuchungPath)
    }

    private static func host(_ url: URL, containsAny needles: [String]) -> Bool {
        let host = (url.host ?? "").lowercased()
        return needles.contains { host.contains($0) }
    }

    private static func bookingPathID(_ url: URL) -> String? {
        NonEmpty.string(url.path.split(separator: "/").last.map(String.init))
    }
}
