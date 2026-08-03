import Foundation

/// Einzel-Allowance → Anzeige-Fragment (SSOT).
public enum BaggageAllowanceFormatting {
    public static func allowancePart(_ allowance: BaggageAllowance) -> String? {
        guard let label = BaggageAllowanceLabels.label(for: allowance.type) else { return nil }
        return buildPart(label: label, pieceCount: allowance.pieceCount, weightKg: allowance.weightKg)
    }

    public static func formattedParts(from allowances: [BaggageAllowance]) -> [String] {
        let sorted = allowances.sorted { $0.type.rawValue < $1.type.rawValue }
        return sorted.compactMap { allowancePart($0) }
    }

    public static func buildPart(label: String, pieceCount: Int?, weightKg: Double?) -> String {
        BaggageAllowancePartBuilder.build(label: label, pieceCount: pieceCount, weightKg: weightKg)
    }

    public static func formatWeightKg(_ weightKg: Double) -> String {
        BaggageWeightFormatting.formatWeightKg(weightKg)
    }

    public static func roundTo1Decimal(_ value: Double) -> Double {
        BaggageWeightFormatting.roundTo1Decimal(value)
    }
}
