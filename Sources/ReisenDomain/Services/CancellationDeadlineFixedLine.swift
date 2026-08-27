import Foundation

public enum CancellationDeadlineFixedLine {
    public static func make() -> CancellationSummaryLine {
        CancellationSummaryLine(
            id: CancellationSummaryLine.fixID,
            kind: .fix,
            text: L10n.string(.bookingCancellationLocked),
            systemImageName: "lock.fill"
        )
    }
}
