import Foundation
import Testing
import ReisenDomain
import ReisenPasteImport

@Test func pasteImportPromptBudget_clipsLongTextKeepingBookingNeedles() {
    let booking = """
        Lufthansa Buchungscode: ABC123
        Ihr Reiseverlauf
        Fr. 18. Dezember 2020: Hamburg – Frankfurt/Main
        """
    let filler = String(repeating: "AGB und Tarifbedingungen ohne Buchungsbezug. ", count: 200)
    let clip = PasteImportPromptBudget.clip(booking + "\n\n" + filler)
    #expect(clip.didClip)
    #expect(clip.text.count <= PasteImportPromptBudget.maxMaterialCharacters)
    #expect(clip.text.contains("ABC123"))
    #expect(clip.text.contains("Reiseverlauf"))
}

@Test func pasteImportPromptBudget_clipsAtLineBoundaryNotMidWord() {
    var lines = (1...80).map { "Buchungscode EXAM\($0) Zeile mit Inhalt" }
    lines.insert("Buchungscode: KEEPME\nAbfahrt: 01.01.2027", at: 0)
    let text = lines.joined(separator: "\n")
    #expect(text.count > PasteImportPromptBudget.maxMaterialCharacters)
    let clip = PasteImportPromptBudget.clip(text)
    #expect(clip.didClip)
    #expect(clip.text.count <= PasteImportPromptBudget.maxMaterialCharacters)
    #expect(clip.text.contains("KEEPME"))
    #expect(!clip.text.hasSuffix("Zeile mit Inh"))
}

@Test func pasteImportPromptBudget_leavesShortTextUnchanged() {
    let text = "Booking Reference: EXAM01\nFlight LH 400"
    let clip = PasteImportPromptBudget.clip(text)
    #expect(clip.didClip == false)
    #expect(clip.text == text)
}

@Test func pasteImportExtractionCoalescer_mergesComplementaryBoardingFragments() throws {
    let codeOnly = PasteImportExtraction(
        title: "UNITED AIRLINES BOARDING PASS",
        confirmationCode: "EXAMUA88"
    )
    let flightOnly = PasteImportExtraction(
        startAt: ticketClock(2026, 7, 18, 7, 0),
        title: "UA 1449",
        locationFrom: "Vancouver YVR",
        locationTo: "San Francisco SFO"
    )
    let coalesced = PasteImportExtractionCoalescer.coalescing([codeOnly, flightOnly])
    #expect(coalesced.count == 1)
    let one = try #require(coalesced.first)
    #expect(one.bookingType == .flight)
    #expect(one.confirmationCode == "EXAMUA88")
    #expect(one.startAt == ticketClock(2026, 7, 18, 7, 0))
    #expect(one.title == "UA 1449")
    let draft = try #require(PasteImportFilter.apply(coalesced).first)
    #expect(draft.bookingType == .flight)
}

@Test func pasteImportExtractionCoalescer_doesNotMergeHotelCodeWithFlightRoute() {
    let hotelCode = PasteImportExtraction(
        title: "Booking.com Confirmation",
        confirmationCode: "EXAMHOTEL1"
    )
    let flightRoute = PasteImportExtraction(
        startAt: ticketClock(2026, 7, 18, 7, 0),
        title: "LH 400",
        locationFrom: "FRA",
        locationTo: "JFK"
    )
    let coalesced = PasteImportExtractionCoalescer.coalescing([hotelCode, flightRoute])
    #expect(coalesced.count == 2)
}

@Test func pasteImportExtractionCoalescer_doesNotMergeConflictingFlightNumbers() {
    let codeSide = PasteImportExtraction(
        title: "LH 400",
        confirmationCode: "EXAMPNR1"
    )
    let otherFlight = PasteImportExtraction(
        startAt: ticketClock(2026, 7, 18, 7, 0),
        title: "UA 1449",
        locationFrom: "YVR",
        locationTo: "SFO"
    )
    let coalesced = PasteImportExtractionCoalescer.coalescing([codeSide, otherFlight])
    #expect(coalesced.count == 2)
}

@Test func pasteImportExtractionCoalescer_keepsTwoCompleteFlights() {
    let first = PasteImportExtraction(
        bookingType: .flight,
        startAt: ticketClock(2026, 7, 18, 7, 0),
        title: "UA 1449",
        confirmationCode: "J1234"
    )
    let second = PasteImportExtraction(
        bookingType: .flight,
        startAt: ticketClock(2026, 7, 22, 18, 41),
        title: "UA 460",
        confirmationCode: "J1234"
    )
    let coalesced = PasteImportExtractionCoalescer.coalescing([first, second])
    #expect(coalesced.count == 2)
}

@Test func pasteImportExtractionCompleter_fillsMatchingMultiSegmentDates() throws {
    let legs = [
        PasteImportExtraction(bookingType: .flight, title: "LH 33", confirmationCode: "ABC123"),
        PasteImportExtraction(bookingType: .flight, title: "LH 28", confirmationCode: "ABC123"),
    ]
    let text = """
        Departure Date: 18 December 2020
        Departure Date: 3 January 2021
        """
    let filled = PasteImportExtractionCompleter.fillingOmittedTravelDates(legs, from: text)
    #expect(filled.count == 2)
    #expect(filled[0].startAt == ticketClock(2020, 12, 18, 0, 0))
    #expect(filled[1].startAt == ticketClock(2021, 1, 3, 0, 0))
}

@Test func pasteImportTravelDateFromText_allStartAtsFromRouteLines() {
    let text = """
        Ihr Reiseverlauf
        Fr. 18. Dezember 2020: Hamburg – Frankfurt/Main
        So. 03. Januar 2021: Frankfurt/Main – Hamburg
        """
    let dates = PasteImportTravelDateFromText.allStartAts(in: text)
    #expect(dates.count == 2)
    #expect(dates[0] == ticketClock(2020, 12, 18, 0, 0))
    #expect(dates[1] == ticketClock(2021, 1, 3, 0, 0))
}

@Test func pasteImportSourceGrounding_dropsFewShotLeakageTitle() {
    let berlin = PasteImportExtraction(
        bookingType: .hotel,
        startAt: ticketClock(2026, 10, 2, 15, 0),
        title: "Apartment am Spreeufer",
        confirmationCode: "EXAMHM5521",
        locationTo: "Berlin"
    )
    let leak = PasteImportExtraction(
        bookingType: .hotel,
        startAt: ticketClock(2026, 9, 3, 15, 0),
        title: "Loft near the canal",
        confirmationCode: "EXAMHM5521",
        locationTo: "Amsterdam"
    )
    let text = """
        Airbnb Buchungsbestätigung
        Bestätigungscode: EXAMHM5521
        Unterkunft: Apartment am Spreeufer
        Adresse: Berlin, Deutschland
        """
    let kept = PasteImportSourceGrounding.keepingGrounded([berlin, leak], in: text)
    #expect(kept.count == 1)
    #expect(kept.first?.title == "Apartment am Spreeufer")
}

@Test func pasteImportSourceGrounding_rejectsCodeAsSubstringOnly() {
    let extraction = PasteImportExtraction(
        bookingType: .hotel,
        startAt: ticketClock(2026, 10, 2, 15, 0),
        title: "Apartment",
        confirmationCode: "MAIN"
    )
    let text = "domain booking without matching confirmation token"
    let kept = PasteImportSourceGrounding.keepingGrounded([extraction], in: text)
    #expect(kept.isEmpty)
}

@Test func pasteImportSourceGrounding_acceptsSegmentedConfirmationCode() {
    let extraction = PasteImportExtraction(
        bookingType: .flight,
        startAt: ticketClock(2026, 7, 18, 7, 0),
        title: "Boarding pass",
        confirmationCode: "EXAM-UA-88"
    )
    let text = "Boarding pass EXAM UA 88 Vancouver to San Francisco"
    let kept = PasteImportSourceGrounding.keepingGrounded([extraction], in: text)
    #expect(kept.count == 1)
}

@Test func pasteImportExtractionTypeHint_setsActivityFromTourTitle() throws {
    let extraction = PasteImportExtraction(
        title: "Schloss Neuschwanstein geführte Tour",
        confirmationCode: "EXAM-GYG-3344"
    )
    let typed = PasteImportExtractionTypeHint.applying([extraction])
    #expect(typed.first?.bookingType == .activity)
    let withLabel = PasteImportExtractionCompleter.fillingOmittedTravelDates(
        typed,
        from: "Tour start: 11 October 2026 10:00"
    )
    #expect(withLabel.first?.startAt != nil)
    let draft = try #require(PasteImportFilter.apply(withLabel).first)
    #expect(draft.bookingType == BookingType.activity)
}

@Test func pasteImportExtractionTypeHint_ignoresBusinessAndTouristenhotel() {
    #expect(
        PasteImportExtractionTypeHint.applying([
            PasteImportExtraction(title: "Business Class Upgrade")
        ]).first?.bookingType == nil
    )
    #expect(
        PasteImportExtractionTypeHint.applying([
            PasteImportExtraction(title: "Touristenhotel am See")
        ]).first?.bookingType == nil
    )
    #expect(
        PasteImportExtractionTypeHint.applying([
            PasteImportExtraction(title: "FlixBus 001 Berlin")
        ]).first?.bookingType == .train
    )
}

@Test func pasteImportExtractionTypeHint_ignoresBroadLabelsLikeEventAndIce() {
    #expect(
        PasteImportExtractionTypeHint.applying([
            PasteImportExtraction(title: "Event Ticket Gate A")
        ]).first?.bookingType == nil
    )
    #expect(
        PasteImportExtractionTypeHint.applying([
            PasteImportExtraction(title: "ICE 701 Hamburg")
        ]).first?.bookingType == nil
    )
}

@Test func pasteImportGenerableMapper_mapsBusAliasesToTrain() {
    #expect(PasteImportGenerableMapper.extraction(from: PasteImportBookingDTO(bookingType: "bus")).bookingType == .train)
    #expect(PasteImportGenerableMapper.extraction(from: PasteImportBookingDTO(bookingType: "FlixBus")).bookingType == .train)
    #expect(PasteImportGenerableMapper.extraction(from: PasteImportBookingDTO(bookingType: "Fernbus")).bookingType == .train)
    #expect(PasteImportGenerableMapper.extraction(from: PasteImportBookingDTO(bookingType: "coach")).bookingType == .train)
}

@Test func pasteImportGenerableMapper_mapsTgvAndSncfToTrain() {
    #expect(PasteImportGenerableMapper.extraction(from: PasteImportBookingDTO(bookingType: "TGV")).bookingType == .train)
    #expect(PasteImportGenerableMapper.extraction(from: PasteImportBookingDTO(bookingType: "SNCF")).bookingType == .train)
}

private func ticketClock(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    var parts = DateComponents()
    parts.year = year
    parts.month = month
    parts.day = day
    parts.hour = hour
    parts.minute = minute
    parts.second = 0
    return Calendar.current.date(from: parts)!
}
