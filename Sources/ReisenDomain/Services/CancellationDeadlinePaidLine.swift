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
            let formattedDeadline = CancellationDeadlineFormatting.formatOrtszeit(
                deadline.deadlineAt,
                dateFormat: "d.M. HH:mm",
                timeZone: deadlineTimeZone
            )
            paidText = L10n.cancellationPaidUntilText(deadlineAt: formattedDeadline)
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
