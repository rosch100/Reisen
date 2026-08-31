import Foundation
import ReisenDomain

enum AirbnbScheduledEventsCancellation {
    private static let freePhrases = [
        "full refund",
        "free cancellation",
        "free cancel",
        "vollständige rückerstattung",
        "kostenlose stornierung",
    ]

    private static let freeTokens: Set<String> = [
        "free",
        "full_refund",
        "free_cancellation",
    ]

    private static let nonRefundableTypePhrases = [
        "no refund",
        "non_refundable",
        "non-refundable",
        "keine rückerstattung",
    ]

    private static let nonRefundableTermPhrases = [
        "non-refundable",
        "not refundable",
        "nicht erstattungsfähig",
    ]

    static func parse(rows: [AirbnbScheduledEventRow]) -> [CancellationDeadline] {
        let row = rows.first(where: { $0.id == "cancellation_visualization" })
        guard let row else { return [] }
        // In this HAR, cancellation milestones are encoded in `cancellation_milestone_modal_v2.entries[]`.
        guard let modalEntries = row.cancellationMilestoneModalV2?.entries else { return [] }
        return modalEntries.compactMap(deadline(from:))
    }

    static func deadline(
        from entry: AirbnbScheduledEventRow.CancellationMilestoneEntry
    ) -> CancellationDeadline? {
        guard let isFree = classifyFreeCancellation(entry) else { return nil }
        guard let deadlineAt = deadlineAt(for: entry, isFree: isFree) else { return nil }
        return CancellationDeadline(
            deadlineAt: deadlineAt,
            policyText: entry.refundTerm ?? entry.timelineTitle,
            isStrict: true,
            isFreeCancellation: isFree
        )
    }

    /// Free-refund "Before" tiers: cancel-by is `end_at` (kein stiller startAt-Fallback).
    /// Non-refundable "After" tiers: `start_at`.
    static func deadlineAt(
        for entry: AirbnbScheduledEventRow.CancellationMilestoneEntry,
        isFree: Bool
    ) -> Date? {
        isFree ? entry.endAt : entry.startAt
    }

    /// Avoid dummy defaults: only set `isFreeCancellation` when we can classify.
    static func classifyFreeCancellation(
        _ entry: AirbnbScheduledEventRow.CancellationMilestoneEntry
    ) -> Bool? {
        let refundType = (entry.refundType ?? "").lowercased()
        let termLower = (entry.refundTerm ?? "").lowercased()
        if matchesNonRefundable(refundType: refundType, termLower: termLower) {
            return false
        }
        if matchesFreeCancellation(refundType: refundType, termLower: termLower) {
            return true
        }
        return nil
    }

    static func matchesNonRefundable(refundType: String, termLower: String) -> Bool {
        // "keine rückerstattung" / "no refund" nur am refund_type — Partial-Terms
        // erwähnen oft „Keine Rückerstattung der ersten Nacht“.
        containsAny(refundType, nonRefundableTypePhrases)
            || containsAny(termLower, nonRefundableTermPhrases)
    }

    static func matchesFreeCancellation(refundType: String, termLower: String) -> Bool {
        if containsAny(termLower, freePhrases) || containsAny(refundType, freePhrases) {
            return true
        }
        return freeTokens.contains(refundType)
    }

    private static func containsAny(_ haystack: String, _ needles: [String]) -> Bool {
        needles.contains { haystack.contains($0) }
    }
}
