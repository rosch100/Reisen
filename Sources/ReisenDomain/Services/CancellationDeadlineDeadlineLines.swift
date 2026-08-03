import Foundation

public enum CancellationDeadlineDeadlineLines {
    public static func append(
        future: [CancellationDeadline],
        hotelTimeZone: TimeZone,
        now: Date,
        into lines: inout [CancellationSummaryLine]
    ) {
        for deadline in future {
            if deadline.isFreeCancellation {
                lines.append(
                    CancellationDeadlineFreeLine.make(
                        deadline: deadline,
                        hotelTimeZone: hotelTimeZone,
                        now: now
                    )
                )
            } else {
                lines.append(
                    CancellationDeadlinePaidLine.make(
                        deadline: deadline,
                        hotelTimeZone: hotelTimeZone
                    )
                )
            }
        }
    }
}
