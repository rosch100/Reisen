import Foundation
import ReisenDomain

/// SwiftData → Domain-Preiszeilen (SSOT-Mapper).
public enum TripCostLineMapping {
    public static func summary(
        bookings: [SDBooking],
        gapPairs: [(amount: Double?, currency: String?)]
    ) -> TripCostSummary {
        let bookingPairs = bookings.map { booking -> (Double?, String?) in
            let rate = booking.rateDetails
            return (rate?.totalPriceAmount, rate?.totalPriceCurrency)
        }
        return TripCostLineBuilder.summary(bookingPairs: bookingPairs, gapPairs: gapPairs)
    }

    public static func summary(bookings: [SDBooking], gaps: [SDGap]) -> TripCostSummary {
        summary(bookings: bookings, gapPairs: gaps.map { ($0.priceAmount, $0.priceCurrencyCode) })
    }
}
