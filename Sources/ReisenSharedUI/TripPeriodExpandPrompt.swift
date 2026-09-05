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

    public static func message(for proposal: TripPeriodExpandOnAssign.Proposal) -> String {
        let range = formattedRange(proposal: proposal)
        return L10n.format(.tripPeriodExpandConfirmMessage, range)
    }

    /// Formatiert Proposal-Start/Ende über `HotelStayDate` (GMT-Anker), nicht Geräte-TZ.
    public static func formattedRange(proposal: TripPeriodExpandOnAssign.Proposal) -> String {
        let start = HotelStayDate.format(proposal.start, dateFormat: "d.M.yyyy")
        let end = HotelStayDate.format(proposal.end, dateFormat: "d.M.yyyy")
        return "\(start) – \(end)"
    }
}
