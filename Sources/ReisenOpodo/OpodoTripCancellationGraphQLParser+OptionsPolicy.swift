import Foundation

extension OpodoTripCancellationGraphQLParser {
    func policyText(for option: OpodoCancellationOptionDTO, label: String?) -> String {
        let pct = option.refundPercentage ?? 0
        let until = option.until ?? ""
        if pct >= 100 {
            let prefix = label ?? OpodoCancellationPolicyLabel.policy
            return "\(prefix) (Full refund until \(until))"
        }
        let amount = option.refundAmount.map { "\($0.amount) \($0.currency)" } ?? ""
        return "Refund \(pct)% \(amount) (until \(until))".trimmingCharacters(in: .whitespaces)
    }
}
