import Foundation
import ReisenDomain

enum AirbnbScheduledEventsCancellation {
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
        guard let startAt = entry.startAt else { return nil }
        guard let isFree = classifyFreeCancellation(entry) else { return nil }
        return CancellationDeadline(
            deadlineAt: startAt,
            policyText: entry.refundTerm ?? entry.timelineTitle,
            isStrict: true,
            isFreeCancellation: isFree
        )
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
        refundType.contains("no refund")
            || refundType.contains("non_refundable")
            || refundType.contains("non-refundable")
            || termLower.contains("non-refundable")
            || termLower.contains("not refundable")
    }

    static func matchesFreeCancellation(refundType: String, termLower: String) -> Bool {
        let freePhrases = ["full refund", "free cancellation", "free cancel"]
        if freePhrases.contains(where: { termLower.contains($0) }) {
            return true
        }
        if freePhrases.contains(where: { refundType.contains($0) }) {
            return true
        }
        return refundType == "free"
            || refundType == "full_refund"
            || refundType == "free_cancellation"
    }
}
