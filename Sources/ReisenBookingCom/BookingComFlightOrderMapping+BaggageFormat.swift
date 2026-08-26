import Foundation

extension BookingComFlightOrderParser {
    func formatAllowance(_ allowance: FlightLuggageAllowance, label: String) -> String {
        var bits: [String] = [label]
        if let pieces = allowance.maxPiece {
            bits.append("\(pieces)×")
        }
        if let weight = allowance.maxWeightPerPiece {
            let unit = allowance.massUnit ?? "KG"
            bits.append("\(weight)\(unit)")
        }
        return bits.joined(separator: " ")
    }
}
