import Foundation
import SwiftData
import ReisenDomain

extension SwiftDataBookingPassengerUpsert {
    static func takeOrCreate(
        _ passenger: BookingPassenger,
        from remaining: inout [SDBookingPassenger],
        booking: SDBooking,
        in context: ModelContext
    ) -> SDBookingPassenger {
        if let existing = SwiftDataBookingMatchHelpers.takeMatching(
            from: &remaining,
            id: passenger.id,
            idOf: \.id,
            contentMatch: {
                $0.passengerNumber == passenger.passengerNumber
                    && ($0.givenName ?? "") == (passenger.givenName ?? "")
                    && ($0.familyName ?? "") == (passenger.familyName ?? "")
            }
        ) {
            return existing
        }
        let created = SDBookingPassenger(
            id: passenger.id,
            booking: booking,
            passengerNumber: passenger.passengerNumber
        )
        context.insert(created)
        return created
    }

    static func apply(_ passenger: BookingPassenger, to model: SDBookingPassenger, booking: SDBooking) {
        model.booking = booking
        model.passengerID = passenger.bookingID
        model.passengerNumber = passenger.passengerNumber
        model.travellerTypeRaw = passenger.travellerType.rawValue
        model.title = passenger.title
        model.givenName = passenger.givenName
        model.familyName = passenger.familyName
        model.secondFamilyName = passenger.secondFamilyName
        model.birthDate = passenger.birthDate
    }
}
