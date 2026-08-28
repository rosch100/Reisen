import Foundation
import Testing
import ReisenDomain
import ReisenSharedUI

@Suite(.serialized)
struct BookingTripDeleteCopyTests {
    @Test func bookingDeleteMessage_manualHasNoSyncWarning() {
        let text = BookingTripActions.bookingDeleteMessage(showsSyncRestoreWarning: false)
        #expect(text == L10n.string(.bookingDeleteConfirmMessage))
        #expect(!text.localizedCaseInsensitiveContains("sync"))
        #expect(!text.contains("Provider-Sync"))
    }

    @Test func bookingDeleteMessage_syncedMentionsProviderSync() {
        let text = BookingTripActions.bookingDeleteMessage(showsSyncRestoreWarning: true)
        #expect(text == L10n.string(.bookingDeleteConfirmMessageSynced))
        let mentionsSync = text.contains("Provider-Sync") || text.localizedCaseInsensitiveContains("provider sync")
        #expect(mentionsSync)
        #expect(text != BookingTripActions.bookingDeleteMessage(showsSyncRestoreWarning: false))
    }

    @Test func tripDeleteMessage_emptyVsWithBookings() {
        let empty = BookingTripActions.tripDeleteMessage(bookingCount: 0)
        let withBookings = BookingTripActions.tripDeleteMessage(bookingCount: 2)
        #expect(empty == L10n.string(.tripDeleteConfirmMessageEmpty))
        #expect(withBookings == L10n.string(.tripDeleteConfirmMessageWithBookings))
        #expect(empty != withBookings)
        #expect(withBookings.contains("Delete trip only") || withBookings.contains("Nur Reise löschen"))
        #expect(withBookings.contains("Delete trip and bookings") || withBookings.contains("Reise und Buchungen löschen"))
    }

    @Test func tripDeleteTitle_namedAndFallback() {
        #expect(BookingTripActions.tripDeleteTitle(named: "Italien") == L10n.format(.tripDeleteConfirmTitleNamed, "Italien"))
        #expect(BookingTripActions.tripDeleteTitle(named: "") == L10n.string(.actionDeleteTripConfirm))
        #expect(BookingTripActions.tripDeleteTitle(named: nil) == L10n.string(.actionDeleteTripConfirm))
    }

    @Test func tripDeleteDialogUsesSingleDestructiveActionLabel() {
        let withBookings = L10n.string(.tripDeleteWithBookings)
        let keep = L10n.string(.tripDeleteKeepBookings)
        #expect(withBookings == "Reise und Buchungen löschen" || withBookings == "Delete trip and bookings")
        #expect(keep == "Nur Reise löschen" || keep == "Delete trip only")
        #expect(withBookings != keep)
    }
}
