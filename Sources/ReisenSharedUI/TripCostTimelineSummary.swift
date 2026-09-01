import Foundation
import SwiftData
import ReisenDomain
import ReisenData

/// Trip-Timeline → `TripCostSummary` (macOS + iOS Overview).
public enum TripCostTimelineSummary {
    public static func make(
        trip: SDTrip,
        bookings: [SDBooking],
        allGaps: [SDGap]
    ) -> TripCostSummary {
        let saved = TripGapTimeline.savedGapsByKey(allGaps: allGaps, tripID: trip.id)
        let computed = TripGapTimeline.computedGaps(trip: trip, bookings: bookings)
        let gapPairs: [(Double?, String?)] = computed.map { gap in
            let model = saved[gap.identityKey]
            return (model?.priceAmount, model?.priceCurrencyCode)
        }
        return TripCostLineMapping.summary(bookings: bookings, gapPairs: gapPairs)
    }
}
