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
        let givenName = parts.dropLast().joined(separator: " ").nilIfEmpty

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

extension String {
    fileprivate var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
