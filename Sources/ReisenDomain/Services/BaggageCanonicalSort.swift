import Foundation

public enum BaggageCanonicalSort {
    public static func lessThan(
        _ lhs: BaggageCanonicalAllowances.CanonicalAllowance,
        _ rhs: BaggageCanonicalAllowances.CanonicalAllowance
    ) -> Bool {
        if lhs.type.rawValue != rhs.type.rawValue {
            return lhs.type.rawValue < rhs.type.rawValue
        }
        if lhs.pieceCount != rhs.pieceCount {
            return BaggageOptionalCompare.intLessThan(lhs.pieceCount, rhs.pieceCount)
        }
        return BaggageOptionalCompare.doubleLessThan(
            lhs.weightKgRounded1Decimal,
            rhs.weightKgRounded1Decimal
        )
    }
}
