import Foundation
import ReisenDomain

extension OpodoFlightPassengersGraphQL {
    static func joinBaggage(from passengers: [BookingPassenger], baggageJSON: String) throws -> [BookingPassenger] {
        let envelope = try OpodoGraphQLRequest.decode(
            OpodoFlightBaggageEnvelope.self,
            from: baggageJSON,
            invalid: OpodoFlightPassengersError.invalidJSON
        )
        var mutable = passengers

        for t in envelope.data.baggageInfo.travellers ?? [] {
            guard let idx = passengerIndex(forNumPassenger: t.numPassenger ?? -1, in: mutable) else {
                continue
            }
            mutable[idx].baggageAllowances = allowances(for: t, passengerID: mutable[idx].id)
        }

        return mutable
    }

    private static func passengerIndex(forNumPassenger num: Int, in passengers: [BookingPassenger]) -> Int? {
        // passengerNumber is 1..n derived by index in parseTravellers.
        let i = num - 1
        guard passengers.indices.contains(i) else { return nil }
        return i
    }
}
