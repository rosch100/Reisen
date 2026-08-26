import Foundation
import SwiftData
import ReisenDomain

enum SwiftDataBookingBaggageUpsert {
    static func upsert(_ allowances: [BaggageAllowance], on passenger: SDBookingPassenger, in context: ModelContext) {
        var remaining = passenger.baggageAllowances ?? []
        var kept: [SDBaggageAllowance] = []

        for allowance in allowances {
            let model = takeOrCreate(allowance, from: &remaining, passenger: passenger, in: context)
            apply(allowance, to: model, passenger: passenger)
            kept.append(model)
        }

        SwiftDataBookingMatchHelpers.deleteAll(remaining, in: context)
        passenger.baggageAllowances = kept
    }
}
