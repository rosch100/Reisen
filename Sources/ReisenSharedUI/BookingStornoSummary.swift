import SwiftUI
import ReisenDomain
import ReisenData

/// UI-Zeile für Storno-Zusammenfassung (Domain-Line + Urgency-Farbe).
public struct BookingStornoSummaryLine: Identifiable, Equatable {
    public let id: String
    public let systemImage: String
    public let text: String
    public let color: Color

    public init(id: String, systemImage: String, text: String, color: Color) {
        self.id = id
        self.systemImage = systemImage
        self.text = text
        self.color = color
    }
}

public enum BookingStornoSummary {
    public static func lines(
        for booking: SDBooking,
        now: Date = Date()
    ) -> [BookingStornoSummaryLine] {
        guard !booking.resolvedCancellationDeadlines.isEmpty else { return [] }

        let domainDeadlines = booking.resolvedCancellationDeadlines.map(DomainMapper.deadline(from:))
        let summaryLines = CancellationDeadlineDisplayService().summaryLines(
            deadlines: domainDeadlines,
            hotelTimeZone: booking.resolvedHotelTimeZone,
            now: now
        )

        return summaryLines.map { line in
            BookingStornoSummaryLine(
                id: line.id.uuidString,
                systemImage: line.systemImageName,
                text: line.text,
                color: color(for: line)
            )
        }
    }

    public static func color(for line: CancellationSummaryLine) -> Color {
        switch line.kind {
        case .fix, .paid:
            return .secondary
        case .free:
            guard let urgency = line.urgency else { return .secondary }
            switch urgency {
            case .ok: return .green
            case .warning: return .orange
            case .critical: return .red
            case .fix: return .secondary
            }
        }
    }
}
