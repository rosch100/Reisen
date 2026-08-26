import Foundation
import ReisenDomain

extension Check24FlightPassengersAndLuggageParser {
    func baggageAllowance(
        type: BaggageType,
        piecesByType: [BaggageType: Int],
        weightKgByType: [BaggageType: Double]
    ) -> BaggageAllowance? {
        let pieces = piecesByType[type]
        guard let pieces, pieces > 0 else { return nil }
        let weightKg = weightKgByType[type]
        return BaggageAllowance(
            type: type,
            pieceCount: pieces > 0 ? pieces : nil,
            weightKg: weightKg != nil && (weightKg ?? 0) > 0 ? weightKg : nil
        )
    }
}
