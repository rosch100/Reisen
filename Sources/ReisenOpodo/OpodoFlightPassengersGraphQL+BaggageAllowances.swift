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
                        type: baggageType(from: bag.type),
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

    static func baggageType(from raw: String?) -> BaggageType {
        switch (raw ?? "").uppercased() {
        case "CHECKED_BAG": return .checkedBag
        case "CABIN_BAG": return .cabinBag
        case "PERSONAL_ITEM": return .personalItem
        default: return .unknown
        }
    }
}
