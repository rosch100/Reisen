import Foundation
import ReisenDomain

/// Heuristischer Parser für Stornofristen aus Opodo-HTML / Policy-Strings.
/// Primär: GraphQL `cancellationOptions`; Fallback: sichtbarer Text inkl. Opodo-Formate.
public struct OpodoCancellationDeadlineParser: Sendable {
    public init() {}

    public func parseDeadlines(from html: String) -> [CancellationDeadline] {
        var deadlines: [CancellationDeadline] = []

        // Keyword-Fenster (ISO/EN-Keywords; kein DE-Label-SSOT)
        deadlines.append(contentsOf: parseKeywordWindows(from: html))

        return dedupeDeadlines(deadlines)
    }

    func dedupeDeadlines(_ deadlines: [CancellationDeadline]) -> [CancellationDeadline] {
        var byKey: [String: CancellationDeadline] = [:]
        for deadline in deadlines {
            let key = "\(Int(deadline.deadlineAt.timeIntervalSince1970))"
            if let existing = byKey[key] {
                // Bei gleichem Zeitpunkt: kostenfrei / Stornierungsrichtlinie bevorzugen.
                if deadline.isFreeCancellation && !existing.isFreeCancellation {
                    byKey[key] = deadline
                } else if deadline.isFreeCancellation == existing.isFreeCancellation,
                          (deadline.policyText?.contains(OpodoCancellationPolicyLabel.policy) == true) {
                    byKey[key] = deadline
                }
            } else {
                byKey[key] = deadline
            }
        }
        return byKey.values.sorted { $0.deadlineAt < $1.deadlineAt }
    }
}
