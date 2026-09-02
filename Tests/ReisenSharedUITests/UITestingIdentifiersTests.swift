import Testing
import ReisenSharedUI
import ReisenData

@Test func uiTestingIdentifiers_areStableAndSeeded() {
    #expect(UITestingIdentifiers.sidebar == "reisen.sidebar")
    #expect(UITestingIdentifiers.detail == "reisen.detail")
    #expect(UITestingIdentifiers.inspector == "reisen.inspector")
    #expect(UITestingIdentifiers.settings == "reisen.settings")
    #expect(UITestingIdentifiers.syncChrome == "reisen.sync.chrome")
    #expect(UITestingIdentifiers.bookingEditor == "reisen.booking.editor")
    #expect(UITestingIdentifiers.bookingEditorSave == "reisen.booking.editor.save")
    #expect(UITestingIdentifiers.emptyState == "reisen.empty-state")
    #expect(UITestingIdentifiers.addBooking == "reisen.action.add-booking")
    #expect(UITestingIdentifiers.tripEditor == "reisen.trip.editor")
    #expect(UITestingIdentifiers.tripEditorTitleField == "reisen.trip.editor.title")
    #expect(UITestingIdentifiers.tripEditorSave == "reisen.trip.editor.save")
    #expect(UITestingIdentifiers.assignBookingsSheet == "reisen.assign-bookings.sheet")
    #expect(UITestingIdentifiers.assignBookingsConfirm == "reisen.assign-bookings.confirm")
    #expect(UITestingIdentifiers.gapEditor == "reisen.gap.editor")
    #expect(UITestingIdentifiers.gapEditorTitleField == "reisen.gap.editor.title")
    #expect(UITestingIdentifiers.gapEditAction == "reisen.gap.edit")
    #expect(UITestingIdentifiers.gapEditorSave == "reisen.gap.editor.save")
    #expect(UITestingIdentifiers.emptyStateNewTrip == "reisen.empty-state.new-trip")
    #expect(UITestingIdentifiers.bookingEditorTitle == "reisen.booking.editor.title")
    #expect(UITestingIdentifiers.settingsNotificationToggle == "reisen.settings.notification-toggle")
    #expect(UITestingIdentifiers.pasteImportReview == "reisen.paste-import.review")
    #expect(UITestingIdentifiers.pasteImportAccept == "reisen.paste-import.accept")
    #expect(UITestingIdentifiers.bookingDetailEdit == "reisen.booking.detail.edit")
    #expect(UITestingIdentifiers.assignBookingsAction == "reisen.action.assign-bookings")
    #expect(
        UITestingIdentifiers.assignBookingsCandidate(UITestingSeed.openBookingID)
            == "reisen.assign-bookings.candidate.\(UITestingSeed.openBookingID.uuidString)"
    )
    #expect(UITestingIdentifiers.openBookingsMailbox == "reisen.open-bookings.mailbox")
    #expect(UITestingIdentifiers.elapsedOpenBookingsMailbox == "reisen.elapsed-open-bookings.mailbox")
    #expect(UITestingIdentifiers.deleteTripMenu == "reisen.action.delete-trip")
    #expect(UITestingIdentifiers.deleteBookingMenu == "reisen.action.delete-booking")
    #expect(UITestingIdentifiers.sidebarExpandBookings == "reisen.action.expand-sidebar-bookings")
    #expect(UITestingIdentifiers.bookingCreateDraftTimeline == "reisen.booking.create-draft.timeline")
    #expect(UITestingIdentifiers.bookingCreateDraftSidebar == "reisen.booking.create-draft.sidebar")
    #expect(UITestingIdentifiers.tripDeleteDialog == "reisen.dialog.delete-trip")
    #expect(UITestingIdentifiers.splitDivider == "reisen.split.divider")
    #expect(UITestingIdentifiers.tripMultiSelectionSummary == "reisen.trip.multi-selection-summary")
    #expect(UITestingIdentifiers.openBookingsContent == "reisen.open-bookings.content")
    #expect(UITestingIdentifiers.deleteBookingMenuTitleDE == "Löschen…")
    #expect(UITestingIdentifiers.removeFromTripMenuTitleDE == "Von Reise entfernen…")
    #expect(UITestingIdentifiers.copyConfirmationMenuTitleDE == "Buchungsnr. kopieren")
    #expect(UITestingIdentifiers.newTripMenuTitleDE == "Neue Reise…")
    #expect(UITestingIdentifiers.assignBookingsMenuTitleDE == "Buchungen zuordnen…")
    #expect(UITestingIdentifiers.editGapMenuTitleDE == "Lücke bearbeiten…")
    #expect(UITestingIdentifiers.seededTripRow == UITestingIdentifiers.tripRow(UITestingSeed.tripID))
    #expect(UITestingIdentifiers.seededBookingRow == UITestingIdentifiers.bookingRow(UITestingSeed.bookingID))
    #expect(UITestingIdentifiers.seededTimelineBookingRow == UITestingIdentifiers.timelineBookingRow(UITestingSeed.bookingID))
    #expect(UITestingIdentifiers.seededOpenBookingRow == UITestingIdentifiers.bookingRow(UITestingSeed.openBookingID))
    #expect(UITestingIdentifiers.seededGapRow == UITestingIdentifiers.gapRow(
        timelineItemID: UITestingSeed.seededGapTimelineItemID
    ))
    #expect(UITestingIdentifiers.seededOpenBookingTitle2 == UITestingSeed.openBookingTitle2)
    #expect(
        UITestingIdentifiers.timelineBookingRow(UITestingSeed.bookingID)
            != UITestingIdentifiers.bookingRow(UITestingSeed.bookingID)
    )
    #expect(
        UITestingIdentifiers.contentOpenBookingRow(UITestingSeed.openBookingID2)
            != UITestingIdentifiers.bookingRow(UITestingSeed.openBookingID2)
    )
    #expect(
        UITestingIdentifiers.seededContentOpenBookingRow2
            == UITestingIdentifiers.contentOpenBookingRow(UITestingSeed.openBookingID2)
    )
    #expect(UITestingIdentifiers.gapRow(timelineItemID: "gap|demo") == "reisen.gap.gap|demo")
}
