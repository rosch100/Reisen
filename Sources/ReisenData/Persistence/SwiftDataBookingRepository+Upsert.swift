import Foundation
import SwiftData
import ReisenDomain

extension SwiftDataBookingRepository {
    public func upsert(_ booking: Booking) throws {
        let model = try SwiftDataBookingResolve.model(for: booking, in: modelContext)
        SwiftDataBookingFieldApply.applyScalars(booking, to: model)
        SwiftDataBookingDeadlineUpsert.upsert(booking.cancellationDeadlines, on: model, in: modelContext)
        SwiftDataBookingPassengerUpsert.upsert(booking.passengers, on: model, in: modelContext)
        SwiftDataBookingGuestHintUpsert.upsert(booking.guestHints, on: model, in: modelContext)
        SwiftDataBookingRateDetailsUpsert.upsert(booking.rateDetails, on: model, in: modelContext)
        try SwiftDataBookingFieldApply.applyTripIfPresent(booking.tripID, to: model, in: modelContext)
    }
}
