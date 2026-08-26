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
        if refundType.contains("no refund")
            || refundType.contains("non_refundable")
            || termLower.contains("non-refundable")
            || termLower.contains("not refundable") {
            return false
        }
        if refundType.contains("full")
            || refundType.contains("free")
            || termLower.contains("free cancellation")
            || termLower.contains("full refund") {
            return true
        }
        return nil
    }
}
