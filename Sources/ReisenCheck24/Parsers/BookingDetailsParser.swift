import Foundation
import ReisenDomain

public struct BookingDetailsParser {
    public init() {}

    public func parse(from html: String, bookingType: BookingType) -> ParsedBookingDetails {
        // Normalisierung für HTML-Entities.
        let normalized = html
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&euro;", with: "€")
            .replacingOccurrences(of: "&#8364;", with: "€")
            .replacingOccurrences(of: "\u{00A0}", with: " ")

        let totalPrice = parseTotalPriceAmount(from: normalized)
        let currency = parseCurrency(from: normalized)

        let roomCountAndCategory = parseRoomCountAndCategory(from: normalized)
        let guestCount = parseGuestCount(from: normalized)

        // Meal/Breakfast ist in den vorhandenen Snapshots nicht immer eindeutig als Klartext enthalten.
        // Daher initial nil lassen und später aus anderen Quellen (z.B. Activity-JSON) füllen.
        let includedBreakfast: Bool? = nil
        let boardTypeRaw: String? = nil

        // Flights/Fähren: erste Implementierung (fail-soft) – wenn es im HTML nicht vorkommt, bleibt es nil.
        let airline: String?
        let passengerCount: Int?
        let baggageInfoRaw: String?
        if bookingType == .hotel {
            airline = nil
            passengerCount = nil
            baggageInfoRaw = nil
        } else {
            airline = parseFirstMatch(forKeyOrLabel: "airline", in: normalized)
                ?? parseFirstMatch(forKeyOrLabel: "carrier", in: normalized)
            passengerCount = parseFirstInteger(forLabels: ["passenger", "Pax", "Reisende"], in: normalized)
            baggageInfoRaw = nil
        }

        let fingerprint = [
            bookingType.rawValue,
            String(describing: totalPrice),
            String(describing: roomCountAndCategory.roomCount),
            String(describing: roomCountAndCategory.roomCategory),
            String(describing: guestCount)
        ].joined(separator: "|")

        return ParsedBookingDetails(
            rawDetailsFingerprint: fingerprint,
            totalPriceAmount: totalPrice,
            totalPriceCurrency: currency,
            roomCategory: roomCountAndCategory.roomCategory,
            boardTypeRaw: boardTypeRaw,
            includedBreakfast: includedBreakfast,
            guestCount: guestCount,
            roomCount: roomCountAndCategory.roomCount,
            airline: airline,
            passengerCount: passengerCount,
            baggageInfoRaw: baggageInfoRaw
        )
    }
}
