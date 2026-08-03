import Foundation

public enum BaggageOptionalCompare {
    public static func intLessThan(_ lhs: Int?, _ rhs: Int?) -> Bool {
        (lhs ?? -1) < (rhs ?? -1)
    }

    public static func doubleLessThan(_ lhs: Double?, _ rhs: Double?) -> Bool {
        (lhs ?? -1) < (rhs ?? -1)
    }
}
