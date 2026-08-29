import SwiftUI
import ReisenDomain

/// Texte für Buchung löschen / von Reise entfernen / Reise löschen.
public enum BookingTripActions {
    public static var removeFromTripTitle: String { L10n.string(.actionRemoveFromTrip) }
    public static var removeFromTripMessage: String { L10n.string(.tripRemoveFromTripHelp) }

    public static func bookingDeleteTitle(named title: String) -> String {
        L10n.format(.bookingDeleteConfirmTitleNamed, title)
    }

    public static func bookingDeleteMessage(showsSyncRestoreWarning: Bool) -> String {
        L10n.string(showsSyncRestoreWarning ? .bookingDeleteConfirmMessageSynced : .bookingDeleteConfirmMessage)
    }

    public static func tripDeleteTitle(named title: String?) -> String {
        guard let title, !title.isEmpty else {
            return L10n.string(.actionDeleteTripConfirm)
        }
        return L10n.format(.tripDeleteConfirmTitleNamed, title)
    }

    public static func tripDeleteMessage(bookingCount: Int) -> String {
        bookingCount == 0
            ? L10n.string(.tripDeleteConfirmMessageEmpty)
            : L10n.string(.tripDeleteConfirmMessageWithBookings)
    }
}
