import Foundation

extension OpodoTripCancellationGraphQLParser {
    func policyText(for option: OpodoCancellationOptionDTO, label: String?) -> String {
        let pct = option.refundPercentage ?? 0
        let until = option.until ?? ""
        if pct >= 100 {
            let prefix = label ?? "Stornierungsrichtlinie"
            return "\(prefix) (Vollständige Rückerstattung bis \(until))"
        }
        let amount = option.refundAmount.map { "\($0.amount) \($0.currency)" } ?? ""
        return "Erstattung \(pct)% \(amount) (bis \(until))".trimmingCharacters(in: .whitespaces)
    }
}
