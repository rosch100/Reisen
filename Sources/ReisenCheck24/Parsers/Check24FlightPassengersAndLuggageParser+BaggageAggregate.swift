import Foundation
import ReisenDomain

extension Check24FlightPassengersAndLuggageParser {
    func aggregateBaggage(
        from included: [IncludedLuggageItem]
    ) -> (piecesByType: [BaggageType: Int], weightKgByType: [BaggageType: Double]) {
        var piecesByType: [BaggageType: Int] = [:]
        var weightKgByType: [BaggageType: Double] = [:]

        for item in included {
            let mappedType = baggageType(from: item.type)
            piecesByType[mappedType, default: 0] += item.pieces

            if let weight = item.weightKg, weight > 0 {
                // Keep the maximum observed per-piece weight for that type.
                weightKgByType[mappedType] = max(weightKgByType[mappedType] ?? 0, weight)
            }
        }
        return (piecesByType, weightKgByType)
    }
}
