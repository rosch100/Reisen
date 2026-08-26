import Foundation
import ReisenDomain

extension Check24FlightPassengersAndLuggageParser {
    func makeBaggageAllowances(
        piecesByType: [BaggageType: Int],
        weightKgByType: [BaggageType: Double]
    ) -> [BaggageAllowance] {
        piecesByType.keys.compactMap { type in
            baggageAllowance(type: type, piecesByType: piecesByType, weightKgByType: weightKgByType)
        }
        // Stabilize output ordering for tests and deterministic persistence:
        .sorted { $0.type.rawValue < $1.type.rawValue }
    }
}
