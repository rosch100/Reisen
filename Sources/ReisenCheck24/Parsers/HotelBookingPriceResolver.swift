import Foundation
import ReisenDomain

/// SSOT: Gesamtpreis bei Mehrzimmer-Buchungen (Check24).
///
/// Check24 liefert oft eine Activity pro Zimmer, die Detailseite aber den
/// Bestell-Gesamtpreis. Dann darf der Gesamtpreis nicht je Zimmer übernommen werden.
public enum HotelBookingPriceResolver: Sendable {
    public static func resolve(
        booking: ParsedBooking,
        siblings: [ParsedBooking],
        detail: ParsedBookingDetails?
    ) -> BookingRateDetails? {
        let sameStaySiblings = siblings.filter { isSameHotelStay($0, booking) }
        let detailRoomCount = detail?.roomCount
        let hasLinkedMultiRoomActivities = sameStaySiblings.count > 1

        // Mehrere Activities = je Zimmer eine Position → Katalogpreis behalten.
        let useCatalogPrice =
            booking.catalogPriceAmount != nil
            && hasLinkedMultiRoomActivities

        // Eine Activity, Detailseite mit mehreren Zimmern → Bestell-Gesamtpreis.
        let useDetailOrderTotal =
            !hasLinkedMultiRoomActivities
            && (detailRoomCount ?? 0) > 1
            && detail?.totalPriceAmount != nil

        let amount: Double?
        let currency: String?
        let roomCount: Int?
        let roomCategory: String?

        if useCatalogPrice {
            amount = booking.catalogPriceAmount
            currency = booking.catalogPriceCurrency ?? detail?.totalPriceCurrency
            roomCount = booking.catalogRoomCount ?? 1
            roomCategory = booking.catalogRoomCategory ?? detail?.roomCategory
        } else if useDetailOrderTotal {
            amount = detail?.totalPriceAmount
            currency = detail?.totalPriceCurrency ?? booking.catalogPriceCurrency
            roomCount = detailRoomCount
            roomCategory = detail?.roomCategory ?? booking.catalogRoomCategory
        } else {
            amount = detail?.totalPriceAmount ?? booking.catalogPriceAmount
            currency = detail?.totalPriceCurrency ?? booking.catalogPriceCurrency
            roomCount = detail?.roomCount ?? booking.catalogRoomCount
            roomCategory = detail?.roomCategory ?? booking.catalogRoomCategory
        }

        let boardRaw = detail?.boardTypeRaw
        let hasAny =
            amount != nil
            || roomCount != nil
            || roomCategory != nil
            || detail?.guestCount != nil
            || boardRaw != nil
            || detail?.includedBreakfast != nil
            || detail?.airline != nil
            || detail?.passengerCount != nil
            || detail?.baggageInfoRaw != nil

        guard hasAny else { return nil }

        return BookingRateDetails(
            rawDetailsFingerprint: detail?.rawDetailsFingerprint,
            totalPriceAmount: amount,
            totalPriceCurrency: currency,
            roomCategory: roomCategory,
            boardType: BookingBoardType(rawValue: boardRaw ?? "") ?? .unknown,
            includedBreakfast: detail?.includedBreakfast,
            guestCount: detail?.guestCount,
            roomCount: roomCount,
            airline: detail?.airline,
            passengerCount: detail?.passengerCount,
            baggageInfoRaw: detail?.baggageInfoRaw,
            lastParsedAt: Date()
        )
    }

    private static func isSameHotelStay(_ a: ParsedBooking, _ b: ParsedBooking) -> Bool {
        guard a.type == .hotel, b.type == .hotel else { return false }
        let aTitle = (a.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let bTitle = (b.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !aTitle.isEmpty, aTitle == bTitle else { return false }

        let calendar = Calendar.current
        return calendar.isDate(a.startAt, inSameDayAs: b.startAt)
            && calendar.isDate(a.endAt, inSameDayAs: b.endAt)
    }
}
