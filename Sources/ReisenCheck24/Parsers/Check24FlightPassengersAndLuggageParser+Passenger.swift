import Foundation
import ReisenDomain

extension Check24FlightPassengersAndLuggageParser {
    func passenger(
        from fullName: String,
        number: Int,
        travellerType: TravellerType,
        baggageAllowances: [BaggageAllowance]
    ) -> BookingPassenger {
        let parts = fullName
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let familyName = parts.last
        let givenName = NonEmpty.string(parts.dropLast().joined(separator: " "))

        return BookingPassenger(
            passengerNumber: number,
            travellerType: travellerType,
            title: nil,
            givenName: givenName,
            familyName: familyName,
            secondFamilyName: nil,
            birthDate: nil,
            // Create fresh baggage allowance IDs per passenger.
            baggageAllowances: copyBaggageAllowances(baggageAllowances)
        )
    }

    func copyBaggageAllowances(_ baggageAllowances: [BaggageAllowance]) -> [BaggageAllowance] {
        baggageAllowances.map { existing in
            BaggageAllowance(
                type: existing.type,
                pieceCount: existing.pieceCount,
                weightKg: existing.weightKg,
                sectionID: existing.sectionID,
                airlineCode: existing.airlineCode,
                fromLabel: existing.fromLabel,
                toLabel: existing.toLabel
            )
        }
    }
}
