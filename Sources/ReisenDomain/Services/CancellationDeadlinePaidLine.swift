import Foundation

public enum CancellationDeadlinePaidLine {
    public static func make(
        deadline: CancellationDeadline,
        hotelTimeZone: TimeZone
    ) -> CancellationSummaryLine {
        let deadlineTimeZone = CancellationDeadlineFormatting.timeZone(
            for: deadline,
            fallback: hotelTimeZone
        )
        let paidText: String
        if let policy = deadline.policyText, !policy.isEmpty {
            paidText = policy
        } else {
            paidText = "Kostenpflichtig stornierbar bis \(CancellationDeadlineFormatting.formatOrtszeit(deadline.deadlineAt, dateFormat: "d.M. HH:mm", timeZone: deadlineTimeZone))"
        }
        return CancellationSummaryLine(
            id: deadline.id,
            kind: .paid,
            text: paidText,
            systemImageName: "tag.fill",
            urgency: nil
        )
    }
}
