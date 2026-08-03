import Foundation

extension ActivityListParser {
    func activityPayment(from activity: [String: Any]) -> (amount: Double?, currency: String?) {
        guard let payment = activity["payment"] as? [String: Any] else {
            return (nil, nil)
        }
        let amount = paymentAmount(from: payment)
        return (amount, paymentCurrency(amount: amount, payment: payment))
    }
}
