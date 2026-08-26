import Foundation
import SwiftData
import ReisenDomain

extension SwiftDataBookingFieldApply {
    /// Assigns trip when `tripID` is present; leaves existing relationship when nil.
    static func applyTripIfPresent(_ tripID: UUID?, to model: SDBooking, in context: ModelContext) throws {
        guard let tripID else {
            // Intentionally keep existing relationship:
            // Sync drafts don't carry trip assignment, but Upsert must not wipe it.
            // Unassignment is done explicitly via `TripRepository.assignBooking(..., toTripID: nil)`.
            return
        }
        let tripDescriptor = FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == tripID })
        guard let trip = try context.fetch(tripDescriptor).first else {
            throw RepositoryError.notFound("Trip \(tripID)")
        }
        model.trip = trip
    }
}
