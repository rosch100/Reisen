import Foundation
import Testing
import ReisenDomain
import ReisenPasteImport

@Test func pasteImportGenerableMapper_dropsLabelConfirmationCodes() {
    let dto = PasteImportBookingDTO(confirmationCode: "Booking reference")
    #expect(PasteImportGenerableMapper.extraction(from: dto).confirmationCode == nil)
}

@Test func pasteImportConfirmationCode_rejectsLabelsAndInitials() {
    #expect(PasteImportConfirmationCode.sanitize("Booking reference") == nil)
    #expect(PasteImportConfirmationCode.sanitize("PNR") == nil)
    #expect(PasteImportConfirmationCode.sanitize("Auftragsnummer") == nil)
    #expect(PasteImportConfirmationCode.sanitize("RS") == nil)
    #expect(PasteImportConfirmationCode.sanitize("JL") == nil)
}

@Test func pasteImportConfirmationCode_keepsPNRAndOrderNumbers() {
    #expect(PasteImportConfirmationCode.sanitize("EXAM04") == "EXAM04")
    #expect(PasteImportConfirmationCode.sanitize("EXAM05A") == "EXAM05A")
    #expect(PasteImportConfirmationCode.sanitize(" EXAM06 ") == "EXAM06")
    #expect(PasteImportConfirmationCode.sanitize("EXAM03") == "EXAM03")
}

@Test func pasteImportConfirmationCode_rejectsPriceLookingTotals() {
    #expect(PasteImportConfirmationCode.sanitize("25.200.000") == nil)
    #expect(PasteImportConfirmationCode.sanitize("25200000") == nil)
}

@Test func pasteImportTravelDateFromText_usesDepartureNotBookingDate() throws {
    let text = """
        Booking Date
        14 July 2026
        Departure Date
        15 August 2026
        Tour Duration
        4D3N
        TOTAL
        25.200.000
        """
    let start = try #require(PasteImportTravelDateFromText.startAt(in: text))
    #expect(start == ticketWallClock(2026, 8, 15, 0, 0))
}

@Test func pasteImportTravelDateFromText_parsesDateOnSameLabelLine() throws {
    let start = try #require(
        PasteImportTravelDateFromText.startAt(in: "Departure Date: 15 August 2026")
    )
    #expect(start == ticketWallClock(2026, 8, 15, 0, 0))
}

@Test func pasteImportTravelDateFromText_ignoresDatePaidPrefix() {
    #expect(PasteImportTravelDateFromText.startAt(in: "Date paid\n15 August 2026") == nil)
}

@Test func pasteImportTravelDateFromText_ignoresBookingDateAlone() {
    let text = "Booking Date\n14 July 2026\nOrder ID #1"
    #expect(PasteImportTravelDateFromText.startAt(in: text) == nil)
}

@Test func pasteImportExtractionCompleter_fillsOmittedStartFromSource() throws {
    let extraction = PasteImportExtraction(bookingType: .activity, title: "4D3N Trip")
    let filled = PasteImportExtractionCompleter.fillingOmittedTravelDates(
        [extraction],
        from: "Departure Date\n15 August 2026"
    )
    let start = try #require(filled.first?.startAt)
    #expect(start == ticketWallClock(2026, 8, 15, 0, 0))
}

@Test func pasteImportExtractionCompleter_doesNotOverwriteModelStart() throws {
    let start = ticketWallClock(2026, 8, 8, 7, 45)
    let extraction = PasteImportExtraction(bookingType: .train, startAt: start, title: "ICE")
    let filled = PasteImportExtractionCompleter.fillingOmittedTravelDates(
        [extraction],
        from: "Departure Date\n15 August 2026"
    )
    #expect(filled.first?.startAt == start)
}

@Test func pasteImportExtractionCompleter_skipsWhenMultipleBookingsPresent() {
    let complete = PasteImportExtraction(
        bookingType: .flight,
        startAt: ticketWallClock(2026, 8, 8, 7, 45),
        title: "Leg 1"
    )
    let missing = PasteImportExtraction(bookingType: .flight, title: "Leg 2")
    let filled = PasteImportExtractionCompleter.fillingOmittedTravelDates(
        [complete, missing],
        from: "Departure Date\n15 August 2026"
    )
    #expect(filled[1].startAt == nil)
}

@Test func pasteImportTravelDateFromText_ignoresDateOfIssue() {
    #expect(PasteImportTravelDateFromText.startAt(in: "Date of issue\n15 August 2026") == nil)
}

private func ticketWallClock(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    var parts = DateComponents()
    parts.year = year
    parts.month = month
    parts.day = day
    parts.hour = hour
    parts.minute = minute
    parts.second = 0
    return Calendar.current.date(from: parts)!
}
