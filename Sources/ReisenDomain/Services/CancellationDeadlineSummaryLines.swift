import Foundation

public enum CancellationDeadlineSummaryLines {
    public static func build(
        future: [CancellationDeadline],
        hotelTimeZone: TimeZone,
        now: Date
    ) -> [CancellationSummaryLine] {
        var lines: [CancellationSummaryLine] = []

        if future.isEmpty || !future.contains(where: \.isFreeCancellation) {
            lines.append(CancellationDeadlineFixedLine.make())
        }

        CancellationDeadlineDeadlineLines.append(
            future: future,
            hotelTimeZone: hotelTimeZone,
            now: now,
            into: &lines
        )

        return lines
    }
}
