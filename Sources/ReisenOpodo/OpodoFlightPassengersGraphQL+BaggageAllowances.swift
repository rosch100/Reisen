import Foundation
import ReisenDomain

extension OpodoFlightPassengersGraphQL {
    static func allowances(
        for traveller: OpodoFlightBaggageEnvelope.BaggageTravellerDTO,
        passengerID: UUID
    ) -> [BaggageAllowance] {
        var allowance: [BaggageAllowance] = []
        for section in traveller.sections ?? [] {
            for bag in section.baggageList ?? [] {
                let weightKg = (bag.weight ?? -1) >= 0 ? bag.weight : nil
                allowance.append(
                    BaggageAllowance(
                        passengerID: passengerID,
                        type: BaggageType.parse(bag.type),
                        pieceCount: bag.numPieces,
                        weightKg: weightKg,
                        sectionID: section.id,
                        airlineCode: section.airlineCode
                    )
                )
            }
        }
        return allowance
    }
}
