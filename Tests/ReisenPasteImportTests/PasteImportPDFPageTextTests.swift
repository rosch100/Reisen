import Testing
import ReisenPasteImport

@Test func pasteImportPDFPageText_dropsFareRulesAfterItinerary() throws {
    let itinerary = """
        Lion Air eTicket
        Booking Reference (PNR): HIFRGJ
        IU 723 Labuan Bajo Jakarta 21 Aug 2026 17:05
        """
    let rules = """
        Fare Rules
        Important Notes
        Please arrive at the airport for check-in 2 hours prior to departure.
        Free Baggage Allowance
        """
    let focused = try #require(PasteImportPDFPageText.focused([itinerary, rules]))
    #expect(focused.contains("HIFRGJ"))
    #expect(!focused.contains("Free Baggage Allowance"))
}

@Test func pasteImportPDFPageText_keepsSoleBoilerplatePage() {
    let rules = "Fare Rules\nImportant Notes\nCatatan Penting"
    #expect(PasteImportPDFPageText.focused([rules]) == rules)
}

@Test func pasteImportPDFPageText_keepsLaterItineraryPage() throws {
    let cover = "eTicket"
    let itinerary = "Booking Confirmation\nDeparture Date 15 August 2026\nKomodo Tour"
    let focused = try #require(PasteImportPDFPageText.focused([cover, itinerary]))
    #expect(focused.contains("Komodo Tour"))
    #expect(focused.contains("eTicket"))
}
