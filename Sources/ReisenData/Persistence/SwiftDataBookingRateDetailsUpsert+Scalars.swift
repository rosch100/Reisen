import Foundation
import SwiftData
import ReisenDomain

extension SwiftDataBookingRateDetailsUpsert {
    static func ensureRateDetails(
        _ details: BookingRateDetails,
        on model: SDBooking,
        in context: ModelContext
    ) -> SDBookingRateDetails {
        if let rate = model.rateDetails {
            return rate
        }
        let created = SDBookingRateDetails(id: details.id, booking: model)
        context.insert(created)
        model.rateDetails = created
        return created
    }

    static func applyScalars(_ details: BookingRateDetails, to existing: SDBookingRateDetails) {
        existing.rawDetailsFingerprint = details.rawDetailsFingerprint
        existing.totalPriceAmount = details.totalPriceAmount
        existing.totalPriceCurrency = details.totalPriceCurrency
        existing.roomCategory = details.roomCategory
        existing.boardTypeRaw = details.boardType.rawValue
        existing.includedBreakfast = details.includedBreakfast
        existing.guestCount = details.guestCount
        existing.roomCount = details.roomCount
        existing.airline = details.airline
        existing.passengerCount = details.passengerCount
        existing.baggageInfoRaw = details.baggageInfoRaw
        existing.lastParsedAt = details.lastParsedAt
    }
}
