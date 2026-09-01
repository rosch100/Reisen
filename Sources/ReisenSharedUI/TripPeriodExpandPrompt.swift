import Foundation
import ReisenDomain

/// Texte für die Rückfrage, den Reisezeitraum bei Out-of-Window-Zuweisung zu erweitern.
public enum TripPeriodExpandPrompt {
    public static var title: String {
        L10n.string(.tripPeriodExpandConfirmTitle)
    }

    public static var confirmAction: String {
        L10n.string(.tripPeriodExpandConfirmAction)
    }

    public static var declineAction: String {
        L10n.string(.tripPeriodExpandDeclineAction)
    }

    public static func message(
        for proposal: TripPeriodExpandOnAssign.Proposal,
        calendar: Calendar = .current
    ) -> String {
        let range = formattedRange(proposal: proposal, calendar: calendar)
        return L10n.format(.tripPeriodExpandConfirmMessage, range)
    }

    public static func formattedRange(
        proposal: TripPeriodExpandOnAssign.Proposal,
        calendar: Calendar = .current
    ) -> String {
        let start = proposal.start.formatted(date: .abbreviated, time: .omitted)
        let end = proposal.end.formatted(date: .abbreviated, time: .omitted)
        return "\(start) – \(end)"
    }
}
