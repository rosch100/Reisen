import Foundation

public enum BaggageWeightFormatting {
    public static func formatWeightKg(_ weightKg: Double) -> String {
        let rounded = roundTo1Decimal(weightKg)
        let oneDecimal = String(format: "%.1f", rounded)
        if oneDecimal.hasSuffix(".0") {
            return String(oneDecimal.dropLast(2))
        }
        return oneDecimal
    }

    public static func roundTo1Decimal(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}
