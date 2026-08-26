import Foundation
import SwiftData
import ReisenDomain

enum SwiftDataBookingPassengerUpsert {
    static func upsert(_ passengers: [BookingPassenger], on model: SDBooking, in context: ModelContext) {
        var remaining = model.passengers ?? []
        var kept: [SDBookingPassenger] = []

        for passenger in passengers {
            let sdPassenger = takeOrCreate(passenger, from: &remaining, booking: model, in: context)
            apply(passenger, to: sdPassenger, booking: model)
            SwiftDataBookingBaggageUpsert.upsert(passenger.baggageAllowances, on: sdPassenger, in: context)
            kept.append(sdPassenger)
        }

        SwiftDataBookingMatchHelpers.deleteAll(remaining, in: context)
        model.passengers = kept
    }
}
