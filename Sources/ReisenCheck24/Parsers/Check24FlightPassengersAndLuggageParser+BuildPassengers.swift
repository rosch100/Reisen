import Foundation
import ReisenDomain

extension Check24FlightPassengersAndLuggageParser {
    /// Builds `BookingPassenger` objects by attaching the same baggage allowances to each passenger.
    public func buildPassengers(
        guestNames: [String],
        baggageAllowances: [BaggageAllowance],
        travellerType: TravellerType = .unknown
    ) -> [BookingPassenger] {
        guard !guestNames.isEmpty else { return [] }

        return guestNames.enumerated().map { idx, fullName in
            passenger(from: fullName, number: idx + 1, travellerType: travellerType, baggageAllowances: baggageAllowances)
        }
    }
}
