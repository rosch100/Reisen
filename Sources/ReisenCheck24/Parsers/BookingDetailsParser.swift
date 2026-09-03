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
        let offerFacts = bookingType == .hotel
            ? Check24HotelOfferFactsParser.parse(from: normalized)
            : nil
        let roomCategory = NonEmpty.first(
            roomCountAndCategory.roomCategory,
            offerFacts?.roomCategory
        )
        let boardTypeRaw = offerFacts?.boardTypeRaw
        let includedBreakfast = offerFacts?.includedBreakfast

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
            String(describing: roomCategory),
            String(describing: guestCount),
            String(describing: boardTypeRaw)
        ].joined(separator: "|")

        return ParsedBookingDetails(
            rawDetailsFingerprint: fingerprint,
            totalPriceAmount: totalPrice,
            totalPriceCurrency: currency,
            roomCategory: roomCategory,
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
