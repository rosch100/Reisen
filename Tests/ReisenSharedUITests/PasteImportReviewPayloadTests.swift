import Foundation
import Testing
import ReisenDomain
import ReisenSharedUI

private func sampleDraft() -> BookingEditorDraft {
    BookingEditorDraft.createDefault(tripStartDate: Date(timeIntervalSince1970: 1_700_000_000))
}

@Test @MainActor
func pasteImportReviewPayload_creatingHasNoBookingID() {
    let payload = PasteImportReviewPayload(
        draft: sampleDraft(),
        tripID: nil,
        bookingID: nil,
        index: 1,
        total: 1
    )
    #expect(!payload.isEnriching)
    #expect(payload.bookingID == nil)
    #expect(payload.tripID == nil)
}

@Test @MainActor
func pasteImportReviewPayload_enrichingExposesBookingAndTripIDs() {
    let tripID = UUID()
    let bookingID = UUID()
    let payload = PasteImportReviewPayload(
        draft: sampleDraft(),
        tripID: tripID,
        bookingID: bookingID,
        index: 2,
        total: 3
    )
    #expect(payload.isEnriching)
    #expect(payload.bookingID == bookingID)
    #expect(payload.tripID == tripID)
    #expect(payload.index == 2)
    #expect(payload.total == 3)
}

@Test @MainActor
func pasteImportReviewPresenter_noteSavedClearsPayloadAndRecordsID() {
    let presenter = PasteImportReviewPresenter()
    let bookingID = UUID()
    presenter.present(
        PasteImportReviewPayload(
            draft: sampleDraft(),
            tripID: nil,
            bookingID: nil
        )
    )
    #expect(presenter.payload != nil)

    var advanced = false
    presenter.onQueueAdvance = { advanced = true }
    presenter.noteSaved(bookingID: bookingID)

    #expect(presenter.payload == nil)
    #expect(presenter.lastSavedBookingID == bookingID)
    #expect(advanced)
}

/// Neu-Import: außerhalb des Reisezeitraums bleibt die Buchung offen.
@Test @MainActor
func pasteImportReviewPayload_creating_outsideWindowStaysOpen() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let tripStart = Date(timeIntervalSince1970: 1_700_000_000)
    let tripEnd = tripStart.addingTimeInterval(7 * 86_400)
    let bookingStart = tripEnd.addingTimeInterval(30 * 86_400)
    let bookingEnd = bookingStart.addingTimeInterval(86_400)
    let tripID = UUID()

    let candidate = PasteImportCandidate(
        draft: PasteImportDraft(
            bookingType: .hotel,
            startAt: bookingStart,
            endAt: bookingEnd,
            endAtIsPlaceholder: false,
            status: .unknown
        ),
        match: .none
    )
    let payload = PasteImportReviewPayload.creating(
        candidate: candidate,
        tripID: tripID,
        tripStart: tripStart,
        tripEnd: tripEnd,
        calendar: calendar
    )
    #expect(payload.tripID == nil)
    #expect(payload.entryTripID == tripID)
}

@Test @MainActor
func pasteImportReviewPayload_creating_inWindowKeepsTrip() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let tripStart = Date(timeIntervalSince1970: 1_700_000_000)
    let tripEnd = tripStart.addingTimeInterval(7 * 86_400)
    let tripID = UUID()

    let candidate = PasteImportCandidate(
        draft: PasteImportDraft(
            bookingType: .hotel,
            startAt: tripStart,
            endAt: tripStart.addingTimeInterval(86_400),
            endAtIsPlaceholder: false,
            status: .unknown
        ),
        match: .none
    )
    let payload = PasteImportReviewPayload.creating(
        candidate: candidate,
        tripID: tripID,
        tripStart: tripStart,
        tripEnd: tripEnd,
        calendar: calendar
    )
    #expect(payload.tripID == tripID)
    #expect(payload.entryTripID == tripID)
}

@Test @MainActor
func pasteImportReviewPresenter_cancelClearsWithoutSavedID() {
    let presenter = PasteImportReviewPresenter()
    presenter.present(
        PasteImportReviewPayload(
            draft: sampleDraft(),
            tripID: UUID(),
            bookingID: nil
        )
    )
    var advanced = false
    presenter.onQueueAdvance = { advanced = true }
    presenter.cancel()

    #expect(presenter.payload == nil)
    #expect(presenter.lastSavedBookingID == nil)
    #expect(advanced)
}
