import Foundation
import ReisenDomain

extension BookingComCancellationDeadlineParser {
    func feePolicyText(prefix: String, datePart: String, timePart: String, amount: Double) -> String {
        "\(prefix) \(datePart) \(timePart): € \(feeAmountText(amount))"
    }

    func feeAmountText(_ amount: Double) -> String {
        if abs(amount.rounded() - amount) < 0.000_1 {
            return String(Int(amount.rounded()))
        }
        return String(format: "%.2f", amount).replacingOccurrences(of: ".", with: ",")
    }
}
