import Foundation
import Testing
import ReisenDomain
import ReisenSharedUI

@Test func bookingDeleteMessage_manualHasNoSyncWarning() {
    let text = BookingTripActions.bookingDeleteMessage(showsSyncRestoreWarning: false)
    #expect(text == L10n.string(.bookingDeleteConfirmMessage))
    #expect(text != L10n.string(.bookingDeleteConfirmMessageSynced))
}

@Test func bookingDeleteMessage_syncedMentionsProviderSync() {
    let text = BookingTripActions.bookingDeleteMessage(showsSyncRestoreWarning: true)
    #expect(text == L10n.string(.bookingDeleteConfirmMessageSynced))
    #expect(text != L10n.string(.bookingDeleteConfirmMessage))
}

@Test func tripDeleteMessage_emptyVsWithBookings() {
    #expect(BookingTripActions.tripDeleteMessage(bookingCount: 0) == L10n.string(.tripDeleteConfirmMessageEmpty))
    #expect(BookingTripActions.tripDeleteMessage(bookingCount: 2) == L10n.string(.tripDeleteConfirmMessageWithBookings))
    #expect(
        BookingTripActions.tripDeleteMessage(bookingCount: 0)
            != BookingTripActions.tripDeleteMessage(bookingCount: 2)
    )
}

@Test func tripDeleteTitle_namedAndFallback() {
    #expect(BookingTripActions.tripDeleteTitle(named: "Italien") == L10n.format(.tripDeleteConfirmTitleNamed, "Italien"))
    #expect(BookingTripActions.tripDeleteTitle(named: "") == L10n.string(.actionDeleteTripConfirm))
    #expect(BookingTripActions.tripDeleteTitle(named: nil) == L10n.string(.actionDeleteTripConfirm))
}

@Test func tripDeleteDialogUsesSingleDestructiveActionLabel() {
    #expect(!L10n.string(.tripDeleteWithBookings).isEmpty)
    #expect(!L10n.string(.tripDeleteKeepBookings).isEmpty)
    #expect(L10n.string(.tripDeleteWithBookings) != L10n.string(.tripDeleteKeepBookings))
}
