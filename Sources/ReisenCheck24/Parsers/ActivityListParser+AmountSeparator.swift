import Foundation

extension ActivityListParser {
    func amountDecimalSeparator(in cleaned: String) -> Character {
        let lastComma = cleaned.lastIndex(of: ",")
        let lastDot = cleaned.lastIndex(of: ".")
        if let comma = lastComma, let dot = lastDot {
            return comma > dot ? "," : "."
        }
        if lastComma != nil { return "," }
        return "."
    }
}
