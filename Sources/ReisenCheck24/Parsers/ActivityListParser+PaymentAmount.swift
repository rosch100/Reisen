import Foundation

extension ActivityListParser {
    func paymentAmount(from payment: [String: Any]) -> Double? {
        if let number = payment["amount"] as? Double {
            return number
        }
        if let number = payment["amount"] as? Int {
            return Double(number)
        }
        if let text = payment["amount"] as? String {
            return parseGermanOrEnglishAmount(text)
        }
        return nil
    }
}
