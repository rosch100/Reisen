import Foundation

public enum BaggageCanonicalAllowances {
    public struct CanonicalAllowance: Equatable, Sendable {
        public let type: BaggageType
        public let pieceCount: Int?
        public let weightKgRounded1Decimal: Double?
    }

    public static func canonical(from allowances: [BaggageAllowance]) -> [CanonicalAllowance] {
        allowances.map { allowance in
            CanonicalAllowance(
                type: allowance.type,
                pieceCount: allowance.pieceCount,
                weightKgRounded1Decimal: allowance.weightKg.map {
                    BaggageWeightFormatting.roundTo1Decimal($0)
                }
            )
        }
        .sorted(by: BaggageCanonicalSort.lessThan)
    }
}
