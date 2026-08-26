import Foundation

public enum BaggageAllowancePartBuilder {
    public static func build(label: String, pieceCount: Int?, weightKg: Double?) -> String {
        var bits: [String] = [label]
        if let pieceCount {
            bits.append("\(pieceCount)×")
        }
        if let weightKg {
            bits.append("\(BaggageWeightFormatting.formatWeightKg(weightKg))KG")
        }
        return bits.joined(separator: " ")
    }
}
