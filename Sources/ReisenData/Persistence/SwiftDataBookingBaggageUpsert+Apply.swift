import Foundation
import SwiftData
import ReisenDomain

extension SwiftDataBookingBaggageUpsert {
    static func takeOrCreate(
        _ allowance: BaggageAllowance,
        from remaining: inout [SDBaggageAllowance],
        passenger: SDBookingPassenger,
        in context: ModelContext
    ) -> SDBaggageAllowance {
        if let existing = SwiftDataBookingMatchHelpers.takeMatching(
            from: &remaining,
            id: allowance.id,
            idOf: \.id,
            contentMatch: {
                SwiftDataBookingContentKeys.baggage(
                    typeRaw: $0.baggageTypeRaw,
                    sectionID: $0.sectionID,
                    airlineCode: $0.airlineCode
                ) == SwiftDataBookingContentKeys.baggage(
                    typeRaw: allowance.type.rawValue,
                    sectionID: allowance.sectionID,
                    airlineCode: allowance.airlineCode
                )
            }
        ) {
            return existing
        }
        let model = SDBaggageAllowance(
            id: allowance.id,
            passenger: passenger,
            baggageTypeRaw: allowance.type.rawValue
        )
        context.insert(model)
        return model
    }

    static func apply(_ allowance: BaggageAllowance, to model: SDBaggageAllowance, passenger: SDBookingPassenger) {
        model.passenger = passenger
        model.baggageTypeRaw = allowance.type.rawValue
        model.pieceCount = allowance.pieceCount
        model.weightKg = allowance.weightKg
        model.sectionID = allowance.sectionID
        model.airlineCode = allowance.airlineCode
        model.fromLabel = allowance.fromLabel
        model.toLabel = allowance.toLabel
    }
}
