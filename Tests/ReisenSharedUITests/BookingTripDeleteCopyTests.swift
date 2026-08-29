import Foundation
import Testing
import ReisenDomain
import ReisenSharedUI

@Suite(.serialized)
struct BookingTripDeleteCopyTests {
    private func withGermanCopy(_ body: () -> Void) {
        let previous = L10n.locale
        L10n.locale = Locale(identifier: "de")
        defer { L10n.locale = previous }
        body()
    }

    @Test func bookingDeleteMessage_manualHasNoSyncWarning() {
        withGermanCopy {
            let text = BookingTripActions.bookingDeleteMessage(showsSyncRestoreWarning: false)
            #expect(text == L10n.string(.bookingDeleteConfirmMessage))
            #expect(!text.localizedCaseInsensitiveContains("sync"))
            #expect(!text.contains("Provider-Sync"))
        }
    }

    @Test func bookingDeleteMessage_syncedMentionsProviderSync() {
        withGermanCopy {
            let text = BookingTripActions.bookingDeleteMessage(showsSyncRestoreWarning: true)
            #expect(text == L10n.string(.bookingDeleteConfirmMessageSynced))
            let mentionsSync = text.contains("Provider-Sync") || text.localizedCaseInsensitiveContains("provider sync")
            #expect(mentionsSync)
            #expect(text != BookingTripActions.bookingDeleteMessage(showsSyncRestoreWarning: false))
        }
    }

    @Test func tripDeleteMessage_emptyVsWithBookings() {
        withGermanCopy {
            let empty = BookingTripActions.tripDeleteMessage(bookingCount: 0)
            let withBookings = BookingTripActions.tripDeleteMessage(bookingCount: 2)
            #expect(empty == L10n.string(.tripDeleteConfirmMessageEmpty))
            #expect(withBookings == L10n.string(.tripDeleteConfirmMessageWithBookings))
            #expect(empty != withBookings)
            #expect(withBookings.contains("Delete trip only") || withBookings.contains("Nur Reise löschen"))
            #expect(withBookings.contains("Delete trip and bookings") || withBookings.contains("Reise und Buchungen löschen"))
        }
    }

    @Test func tripDeleteTitle_namedAndFallback() {
        withGermanCopy {
            #expect(BookingTripActions.tripDeleteTitle(named: "Italien") == L10n.format(.tripDeleteConfirmTitleNamed, "Italien"))
            #expect(BookingTripActions.tripDeleteTitle(named: "Italien").contains("Italien"))
            #expect(
                BookingTripActions.tripDeleteTitle(named: "Italien").contains("löschen?")
                    || BookingTripActions.tripDeleteTitle(named: "Italien").localizedCaseInsensitiveContains("delete")
            )
            #expect(BookingTripActions.tripDeleteTitle(named: "") == L10n.string(.actionDeleteTripConfirm))
            #expect(BookingTripActions.tripDeleteTitle(named: nil) == L10n.string(.actionDeleteTripConfirm))
        }
    }

    @Test func tripDeleteDialogUsesSingleDestructiveActionLabel() {
        withGermanCopy {
            let withBookings = L10n.string(.tripDeleteWithBookings)
            let keep = L10n.string(.tripDeleteKeepBookings)
            #expect(withBookings == "Reise und Buchungen löschen" || withBookings == "Delete trip and bookings")
            #expect(keep == "Nur Reise löschen" || keep == "Delete trip only")
            #expect(withBookings != keep)
        }
    }

    @Test func persistFailureTitle_isDedicatedWithoutPlaceholder() {
        withGermanCopy {
            let title = L10n.string(.errorPersistFailed)
            #expect(title == "Speichern fehlgeschlagen" || title == "Save failed")
            #expect(!title.contains("%"))
            #expect(title != L10n.string(.tripAssignFailed))
        }
    }
}
