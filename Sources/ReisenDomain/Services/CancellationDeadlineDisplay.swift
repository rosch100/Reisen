import Foundation

public enum CancellationSummaryLineKind: Equatable, Sendable {
    case fix
    case free
    case paid
}

public struct CancellationSummaryLine: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let kind: CancellationSummaryLineKind
    public let text: String
    public let systemImageName: String

    /// Nur für `.free`. UI kann daraus Farben ableiten.
    public let urgency: CancellationUrgency?

    public init(
        id: UUID,
        kind: CancellationSummaryLineKind,
        text: String,
        systemImageName: String,
        urgency: CancellationUrgency? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.systemImageName = systemImageName
        self.urgency = urgency
    }

    public static let fixID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}

public struct CancellationDeadlineDisplayService: Sendable {
    public init() {}

    /// Wie auf macOS: Nur zukünftige Deadlines + Paid nur unter Vollpreis (Paid mit max. Fee wird ausgefiltert).
    public func deadlinesForDisplay(
        _ deadlines: [CancellationDeadline],
        now: Date
    ) -> [CancellationDeadline] {
        let futureDeadlines = deadlines
            .filter { $0.deadlineAt > now }
            .sorted(by: { $0.deadlineAt < $1.deadlineAt })

        if futureDeadlines.isEmpty { return [] }

        let freeDeadlines = futureDeadlines.filter(\.isFreeCancellation)
        let paidDeadlines = futureDeadlines.filter { !$0.isFreeCancellation }

        let paidAmounts: [Double] = paidDeadlines.compactMap(\.cancellationFeeAmount)

        // Der Buchungspreis entspricht typischerweise dem maximalen kostenpflichtigen Betrag.
        guard let bookingPriceFee = paidAmounts.max() else {
            // Falls wir den Buchungspreis nicht zuverlässig bestimmen können, zeigen wir sicherheitshalber
            // nur kostenlose Optionen an.
            return freeDeadlines
        }

        let epsilon = 0.01

        let paidIdsToShow: Set<UUID> = {
            let candidates = paidDeadlines.filter { deadline in
                guard let amount = deadline.cancellationFeeAmount else { return false }
                return amount < (bookingPriceFee - epsilon)
            }
            return Set(candidates.map(\.id))
        }()

        return futureDeadlines.filter { deadline in
            deadline.isFreeCancellation || paidIdsToShow.contains(deadline.id)
        }
    }

    public func summaryLines(
        deadlines: [CancellationDeadline],
        hotelTimeZone: TimeZone,
        now: Date
    ) -> [CancellationSummaryLine] {
        let futureDeadlinesForDisplay = deadlinesForDisplay(deadlines, now: now)

        // Fix gilt als "zeitbasiert": Wenn es keine zukünftige Free-Cancellation mehr gibt.
        let hasFutureFreeCancellation = futureDeadlinesForDisplay.contains { $0.isFreeCancellation }
        let urgencyService = CancellationUrgencyService()

        var lines: [CancellationSummaryLine] = []

        if futureDeadlinesForDisplay.isEmpty || !hasFutureFreeCancellation {
            lines.append(
                CancellationSummaryLine(
                    id: CancellationSummaryLine.fixID,
                    kind: .fix,
                    text: "Fix (nicht mehr kostenlos stornierbar)",
                    systemImageName: "lock.fill"
                )
            )
        }

        for deadline in futureDeadlinesForDisplay {
            let deadlineTimeZone = timeZone(for: deadline, fallback: hotelTimeZone)
            if deadline.isFreeCancellation {
                let urgency = urgencyService.urgency(for: deadline, now: now)
                lines.append(
                    CancellationSummaryLine(
                        id: deadline.id,
                        kind: .free,
                        text: "Kostenlos stornierbar bis \(formatOrtszeit(deadline.deadlineAt, dateFormat: "d.M. HH:mm", timeZone: deadlineTimeZone))",
                        systemImageName: "checkmark.circle.fill",
                        urgency: urgency
                    )
                )
            } else {
                let paidText: String = {
                    if let policy = deadline.policyText, !policy.isEmpty {
                        return policy
                    }
                    return "Kostenpflichtig stornierbar bis \(formatOrtszeit(deadline.deadlineAt, dateFormat: "d.M. HH:mm", timeZone: deadlineTimeZone))"
                }()

                lines.append(
                    CancellationSummaryLine(
                        id: deadline.id,
                        kind: .paid,
                        text: paidText,
                        systemImageName: "tag.fill",
                        urgency: nil
                    )
                )
            }
        }

        return lines
    }

    private func timeZone(for deadline: CancellationDeadline, fallback: TimeZone) -> TimeZone {
        guard let offsetSeconds = deadline.hotelOffsetSeconds else { return fallback }
        return TimeZone(secondsFromGMT: offsetSeconds) ?? fallback
    }

    private func formatOrtszeit(
        _ date: Date,
        dateFormat: String,
        timeZone: TimeZone
    ) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE_POSIX")
        df.timeZone = timeZone
        df.dateFormat = dateFormat
        return df.string(from: date)
    }
}

