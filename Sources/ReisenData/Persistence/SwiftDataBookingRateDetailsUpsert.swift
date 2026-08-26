import Foundation
import SwiftData
import ReisenDomain

enum SwiftDataBookingRateDetailsUpsert {
    static func upsert(_ details: BookingRateDetails?, on model: SDBooking, in context: ModelContext) {
        guard let details else { return }
        let existing = ensureRateDetails(details, on: model, in: context)
        applyScalars(details, to: existing)
        upsertRooms(details.roomItems, on: existing, in: context)
    }
}
