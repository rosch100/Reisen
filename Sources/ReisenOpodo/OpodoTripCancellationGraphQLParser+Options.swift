import Foundation
import ReisenDomain

extension OpodoTripCancellationGraphQLParser {
    func deadlinesFromCancellationOptions(
        _ options: [OpodoCancellationOptionDTO]?,
        policyLabel: String?
    ) -> [CancellationDeadline] {
        guard let options, !options.isEmpty else { return [] }

        var freeOptions: [CancellationDeadline] = []
        var paid: [CancellationDeadline] = []
        for option in options {
            guard let until = option.until, let parsed = parseISODate(until) else { continue }
            let pct = option.refundPercentage ?? 0
            let deadline = CancellationDeadline(
                deadlineAt: parsed.date,
                policyText: policyText(for: option, label: policyLabel),
                isStrict: true,
                isFreeCancellation: pct >= 100,
                hotelOffsetSeconds: parsed.offsetSeconds,
                cancellationFeeAmount: nil
            )
            if pct >= 100 {
                freeOptions.append(deadline)
            } else {
                paid.append(deadline)
            }
        }

        var result = paid
        if let latestFree = freeOptions.max(by: { $0.deadlineAt < $1.deadlineAt }) {
            result.append(latestFree)
        }
        return result
    }
}
