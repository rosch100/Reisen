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
        let selection = selectPriceFields(
            booking: booking,
            siblings: siblings,
            detail: detail
        )

        let boardRaw = detail?.boardTypeRaw
        let hasAny =
            selection.amount != nil
            || selection.roomCount != nil
            || selection.roomCategory != nil
            || detail?.guestCount != nil
            || boardRaw != nil
            || detail?.includedBreakfast != nil
            || detail?.airline != nil
            || detail?.passengerCount != nil
            || detail?.baggageInfoRaw != nil

        guard hasAny else { return nil }

        return BookingRateDetails(
            rawDetailsFingerprint: detail?.rawDetailsFingerprint,
            totalPriceAmount: selection.amount,
            totalPriceCurrency: selection.currency,
            roomCategory: selection.roomCategory,
            boardType: BookingBoardType.parse(boardRaw),
            includedBreakfast: detail?.includedBreakfast,
            guestCount: detail?.guestCount,
            roomCount: selection.roomCount,
            airline: detail?.airline,
            passengerCount: detail?.passengerCount,
            baggageInfoRaw: detail?.baggageInfoRaw,
            lastParsedAt: Date()
        )
    }
}
