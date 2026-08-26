import Foundation

/// Filter: zukünftige Deadlines; Paid nur unter Vollpreis-Fee (SSOT).
public enum CancellationDeadlineDisplayFilter {
    public static func deadlinesForDisplay(
        _ deadlines: [CancellationDeadline],
        now: Date
    ) -> [CancellationDeadline] {
        let futureDeadlines = CancellationDeadlineFutureFilter.futureSorted(deadlines, now: now)
        if futureDeadlines.isEmpty { return [] }
        return CancellationDeadlineFutureFilter.applyingPaidFilter(futureDeadlines: futureDeadlines)
    }
}
