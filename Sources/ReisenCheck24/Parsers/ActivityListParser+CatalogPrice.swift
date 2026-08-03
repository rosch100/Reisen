import Foundation
import ReisenDomain

extension ActivityListParser {
    func detailsFromCatalogPrice(
        catalogPrice: (amount: Double?, currency: String?),
        roomInfo: (count: Int?, category: String?),
        bookingType: BookingType
    ) -> ParsedBookingDetails? {
        guard let amount = catalogPrice.amount else { return nil }
        let currency = catalogPrice.currency

        let fingerprint = [
            bookingType.rawValue,
            "catalogPrice",
            String(describing: amount),
            String(describing: currency),
            String(describing: roomInfo.count),
            String(describing: roomInfo.category)
        ].joined(separator: "|")

        return ParsedBookingDetails(
            rawDetailsFingerprint: fingerprint,
            totalPriceAmount: amount,
            totalPriceCurrency: currency,
            roomCategory: roomInfo.category,
            boardTypeRaw: nil,
            includedBreakfast: nil,
            guestCount: nil,
            roomCount: roomInfo.count,
            airline: nil,
            passengerCount: nil,
            baggageInfoRaw: nil
        )
    }
}
