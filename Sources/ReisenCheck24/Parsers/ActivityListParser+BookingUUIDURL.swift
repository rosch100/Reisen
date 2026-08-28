import Foundation
import ReisenDomain

enum Check24KundenbereichHost {
    static let hotel = "hotel.check24.de"
    static let flight = "flug.check24.de"
    static let ferry = "ferry.check24.de"

    static func host(for bookingType: BookingType) -> String {
        switch bookingType {
        case .flight:
            return flight
        case .ferry:
            return ferry
        case .hotel, .activity, .carRental, .other:
            return hotel
        }
    }

    static func host(fromDetailURL urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        if let host = url.host?.lowercased() {
            if matchesProductHost(host, product: hotel) { return hotel }
            if matchesProductHost(host, product: flight) { return flight }
            if matchesProductHost(host, product: ferry) { return ferry }
        }
        // Nur Pfad, wenn Host kein Produkt-Portal ist (Query/Titel dürfen nicht mappen).
        let path = url.path.lowercased()
        if path.contains("flug") || path.contains("flight") { return flight }
        if path.contains("ferry") || path.contains("faehre") { return ferry }
        if path.contains("hotel") { return hotel }
        return nil
    }

    private static func matchesProductHost(_ host: String, product: String) -> Bool {
        host == product || host.hasSuffix(".\(product)")
    }
}

extension ActivityListParser {
    func bookingUUIDDetailURL(from activity: [String: Any], bookingType: BookingType) -> String? {
        let uuid = bookingUUID(from: activity)
        guard let uuid, !uuid.isEmpty else { return nil }
        return "https://\(Check24KundenbereichHost.host(for: bookingType))/kundenbereich/buchung/\(uuid)"
    }

    func kundenbereichHost(for bookingType: BookingType) -> String {
        Check24KundenbereichHost.host(for: bookingType)
    }

    private func bookingUUID(from activity: [String: Any]) -> String? {
        let psd = productSpecificData(from: activity)
        if let uuid = psd["booking_uuid"] as? String, !uuid.isEmpty {
            return uuid
        }
        if let uuid = activity["booking_uuid"] as? String, !uuid.isEmpty {
            return uuid
        }
        return nil
    }
}
