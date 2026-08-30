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
