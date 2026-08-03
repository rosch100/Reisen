import Foundation

public struct CancellationDeadlineDisplayService: Sendable {
    public init() {}

    /// Wie auf macOS: Nur zukünftige Deadlines + Paid nur unter Vollpreis (Paid mit max. Fee wird ausgefiltert).
    public func deadlinesForDisplay(
        _ deadlines: [CancellationDeadline],
        now: Date
    ) -> [CancellationDeadline] {
        CancellationDeadlineDisplayFilter.deadlinesForDisplay(deadlines, now: now)
    }

    public func summaryLines(
        deadlines: [CancellationDeadline],
        hotelTimeZone: TimeZone,
        now: Date
    ) -> [CancellationSummaryLine] {
        CancellationDeadlineSummaryLines.build(
            future: deadlinesForDisplay(deadlines, now: now),
            hotelTimeZone: hotelTimeZone,
            now: now
        )
    }
}
