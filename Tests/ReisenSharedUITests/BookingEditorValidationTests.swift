import Foundation
import Testing
import ReisenDomain
import ReisenSharedUI

@Test func bookingEditorValidation_invalidNumber_exposesFieldForFocus() {
    var draft = BookingEditorDraft.createDefault(
        tripStartDate: Date(timeIntervalSince1970: 1_800_000_000)
    )
    draft.title = "Hotel Lissabon"
    draft.totalPriceAmountText = "ungültig"

    do {
        try draft.validate()
        Issue.record("Die Validierung hätte einen Fehler melden müssen.")
    } catch let error as BookingEditorDraft.ValidationError {
        guard case .invalidNumber(_, let focusField) = error else {
            Issue.record("Es wurde der falsche Validierungsfehler gemeldet.")
            return
        }
        #expect(focusField == .price)
    } catch {
        Issue.record("Es wurde ein unerwarteter Fehlertyp gemeldet.")
    }
}

@Test func bookingEditorValidation_ignoresInternalTimezoneOffsetText() throws {
    var draft = BookingEditorDraft.createDefault(
        tripStartDate: Date(timeIntervalSince1970: 1_800_000_000)
    )
    draft.title = "Hotel Lissabon"
    draft.hotelOffsetSecondsText = "kein-offset"
    draft.flightDepartureOffsetSecondsText = "xyz"
    draft.flightArrivalOffsetSecondsText = "abc"
    draft.cancellationDeadlines = [
        CancellationDeadlineDraft(
            deadlineAt: draft.startAt,
            hotelOffsetSecondsText: "bad"
        )
    ]

    try draft.validate()
    #expect(BookingEditorDraft.parseIntOrNil(draft.hotelOffsetSecondsText) == nil)
}

@Test func bookingEditorDraft_preservesInternalOffsetWhenTextMalformed() {
    #expect(BookingEditorDraft.preservedInternalOffset(from: "7200", existing: 3_600) == 7_200)
    #expect(BookingEditorDraft.preservedInternalOffset(from: "kein-offset", existing: 7_200) == 7_200)
    #expect(BookingEditorDraft.preservedInternalOffset(from: "", existing: 7_200) == 7_200)
    #expect(BookingEditorDraft.preservedInternalOffset(from: "bad", existing: nil) == nil)
}
