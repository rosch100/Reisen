import Foundation
import Testing
import ReisenAppCore

@Test func pasteImportEntry_tripEntryKeepsItsTrip() {
    let tripID = UUID()
    #expect(PasteImportEntry.trip(tripID).tripID == tripID)
    #expect(PasteImportEntry.trip(nil).tripID == nil)
}

/// „Offen“ darf keine Reise erben, auch wenn im Reise-Tab noch eine ausgewählt ist.
@Test func pasteImportEntry_openEntryHasNoTrip() {
    #expect(PasteImportEntry.open.tripID == nil)
}

/// Die Übergabe kommt von außen und kennt keinen Reise-Kontext.
@Test func pasteImportEntry_handoffHasNoTrip() {
    #expect(PasteImportEntry.handoff.tripID == nil)
}
