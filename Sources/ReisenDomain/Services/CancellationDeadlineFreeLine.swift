import Foundation

public enum CancellationDeadlineFreeLine {
    public static func make(
        deadline: CancellationDeadline,
        hotelTimeZone: TimeZone,
        now: Date
    ) -> CancellationSummaryLine {
        let deadlineTimeZone = CancellationDeadlineFormatting.timeZone(
            for: deadline,
            fallback: hotelTimeZone
        )
        return CancellationSummaryLine(
            id: deadline.id,
            kind: .free,
            text: "Kostenlos stornierbar bis \(CancellationDeadlineFormatting.formatOrtszeit(deadline.deadlineAt, dateFormat: "d.M. HH:mm", timeZone: deadlineTimeZone))",
            systemImageName: "checkmark.circle.fill",
            urgency: CancellationUrgencyService().urgency(for: deadline, now: now)
        )
    }
}
