import Foundation

public enum CancellationDeadlineFixedLine {
    public static func make() -> CancellationSummaryLine {
        CancellationSummaryLine(
            id: CancellationSummaryLine.fixID,
            kind: .fix,
            text: "Fix (nicht mehr kostenlos stornierbar)",
            systemImageName: "lock.fill"
        )
    }
}
