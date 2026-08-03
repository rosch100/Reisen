import Foundation

extension ActivityListParser {
    func paymentCurrency(amount: Double?, payment: [String: Any]) -> String? {
        if let suffix = payment["suffix"] as? String, suffix.contains("€") {
            return "EUR"
        }
        if amount != nil {
            return "EUR"
        }
        return nil
    }
}
