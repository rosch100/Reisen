import Foundation
import Testing
import ReisenDomain

private let mergeStart = Date(timeIntervalSince1970: 1_800_000_000)
private let mergeEnd = mergeStart.addingTimeInterval(86_400)

private func mergeDraft(_ extraction: PasteImportExtraction) throws -> PasteImportDraft {
    try #require(PasteImportFilter.apply([extraction]).first)
}

/// Extraction mit Werten in allen Feldern, die der Merger füllen darf.
private func mergeFullExtraction() -> PasteImportExtraction {
    PasteImportExtraction(
        bookingType: .hotel,
        startAt: mergeStart,
        endAt: mergeEnd,
        title: "Paste Title",
        confirmationCode: "PASTE-CODE",
        externalUrl: "https://paste.example/x",
        locationFrom: "Paste From",
        locationTo: "Paste To",
        locationFromAddress: "Paste From Address",
        locationToAddress: "Paste To Address",
        operatorName: "Paste Operator",
        status: .confirmed,
        hotelCheckInMinutes: 900,
        hotelCheckOutMinutes: 660,
        hotelOffsetSeconds: 7_200,
        flightDepartureOffsetSeconds: 3_600,
        flightArrivalOffsetSeconds: 10_800,
        passengers: [mergePassenger(number: 9)],
        guestHints: [mergeGuestHint(sourceKey: "paste:hint")],
        rateDetails: mergeRateDetails(currency: "USD"),
        deadlines: [mergeDeadline(at: mergeStart)]
    )
}

private func mergePassenger(number: Int) -> BookingPassenger {
    BookingPassenger(passengerNumber: number, travellerType: .adult)
}

private func mergeGuestHint(sourceKey: String) -> BookingGuestHint {
    BookingGuestHint(title: "Hint", detail: "Detail", sourceKey: sourceKey)
}

private func mergeDeadline(at deadlineAt: Date) -> CancellationDeadline {
    CancellationDeadline(deadlineAt: deadlineAt)
}

private func mergeRateDetails(currency: String) -> BookingRateDetails {
    BookingRateDetails(totalPriceCurrency: currency)
}

@Test func pasteImportMerger_fillsNilConfirmationKeepsProviderAndTrip() throws {
    var existing = Booking(
        provider: .check24,
        bookingType: .hotel,
        title: "Hotel Berlin",
        startAt: mergeStart,
        endAt: mergeEnd,
        lastSyncedAt: mergeStart,
        tripID: UUID()
    )
    existing.externalUrl = "https://check24.example/x"
    let draft = try mergeDraft(
        PasteImportExtraction(
            bookingType: .train,
            startAt: mergeStart.addingTimeInterval(10),
            title: "Ignored Title",
            confirmationCode: "XYZ"
        )
    )

    let merged = PasteImportMerger.fillingGaps(on: existing, from: draft)

    #expect(merged.id == existing.id)
    #expect(merged.provider == .check24)
    #expect(merged.bookingType == .hotel)
    #expect(merged.title == "Hotel Berlin")
    #expect(merged.confirmationCode == "XYZ")
    #expect(merged.externalUrl == "https://check24.example/x")
    #expect(merged.lastSyncedAt == mergeStart)
    #expect(merged.tripID == existing.tripID)
    #expect(merged.startAt == existing.startAt)
    #expect(merged.endAt == existing.endAt)
}

@Test func pasteImportMerger_doesNotOverwriteExistingCode() throws {
    let existing = Booking(
        provider: .opodo,
        bookingType: .flight,
        confirmationCode: "KEEP",
        startAt: mergeStart,
        endAt: mergeStart
    )
    let draft = try mergeDraft(
        PasteImportExtraction(bookingType: .flight, startAt: mergeStart, confirmationCode: "NEW")
    )

    let merged = PasteImportMerger.fillingGaps(on: existing, from: draft)

    #expect(merged.confirmationCode == "KEEP")
}

@Test func pasteImportMerger_treatsWhitespaceStringAsGap() throws {
    let existing = Booking(
        provider: .manual,
        bookingType: .hotel,
        title: "   ",
        confirmationCode: "\n\t",
        startAt: mergeStart,
        endAt: mergeEnd,
        locationTo: ""
    )
    let draft = try mergeDraft(mergeFullExtraction())

    let merged = PasteImportMerger.fillingGaps(on: existing, from: draft)

    #expect(merged.title == "Paste Title")
    #expect(merged.confirmationCode == "PASTE-CODE")
    #expect(merged.locationTo == "Paste To")
}

@Test func pasteImportMerger_fillsEmptyScalarFields() throws {
    let existing = Booking(provider: .manual, bookingType: .hotel, startAt: mergeStart, endAt: mergeEnd)
    let draft = try mergeDraft(mergeFullExtraction())

    let merged = PasteImportMerger.fillingGaps(on: existing, from: draft)

    #expect(merged.title == "Paste Title")
    #expect(merged.confirmationCode == "PASTE-CODE")
    #expect(merged.locationFrom == "Paste From")
    #expect(merged.locationTo == "Paste To")
    #expect(merged.locationFromAddress == "Paste From Address")
    #expect(merged.locationToAddress == "Paste To Address")
    #expect(merged.operatorName == "Paste Operator")
    #expect(merged.hotelCheckInMinutes == 900)
    #expect(merged.hotelCheckOutMinutes == 660)
    #expect(merged.hotelOffsetSeconds == 7_200)
    #expect(merged.flightDepartureOffsetSeconds == 3_600)
    #expect(merged.flightArrivalOffsetSeconds == 10_800)
}

@Test func pasteImportMerger_keepsFilledScalarFields() throws {
    let existing = Booking(
        provider: .manual,
        bookingType: .hotel,
        title: "Own Title",
        confirmationCode: "OWN-CODE",
        startAt: mergeStart,
        endAt: mergeEnd,
        hotelOffsetSeconds: 1,
        flightDepartureOffsetSeconds: 2,
        flightArrivalOffsetSeconds: 3,
        hotelCheckInMinutes: 4,
        hotelCheckOutMinutes: 5,
        locationFrom: "Own From",
        locationTo: "Own To",
        locationFromAddress: "Own From Address",
        locationToAddress: "Own To Address",
        operatorName: "Own Operator"
    )
    let draft = try mergeDraft(mergeFullExtraction())

    let merged = PasteImportMerger.fillingGaps(on: existing, from: draft)

    #expect(merged.title == "Own Title")
    #expect(merged.confirmationCode == "OWN-CODE")
    #expect(merged.locationFrom == "Own From")
    #expect(merged.locationTo == "Own To")
    #expect(merged.locationFromAddress == "Own From Address")
    #expect(merged.locationToAddress == "Own To Address")
    #expect(merged.operatorName == "Own Operator")
    #expect(merged.hotelCheckInMinutes == 4)
    #expect(merged.hotelCheckOutMinutes == 5)
    #expect(merged.hotelOffsetSeconds == 1)
    #expect(merged.flightDepartureOffsetSeconds == 2)
    #expect(merged.flightArrivalOffsetSeconds == 3)
}

@Test func pasteImportMerger_fillsEmptyCollectionsAndRateDetails() throws {
    let existing = Booking(provider: .manual, bookingType: .hotel, startAt: mergeStart, endAt: mergeEnd)
    let draft = try mergeDraft(mergeFullExtraction())

    let merged = PasteImportMerger.fillingGaps(on: existing, from: draft)

    #expect(merged.passengers == draft.passengers)
    #expect(merged.guestHints == draft.guestHints)
    #expect(merged.cancellationDeadlines == draft.deadlines)
    #expect(merged.rateDetails == draft.rateDetails)
}

@Test func pasteImportMerger_keepsNonEmptyCollectionsAndRateDetails() throws {
    let ownPassengers = [mergePassenger(number: 1)]
    let ownHints = [mergeGuestHint(sourceKey: "own:hint")]
    let ownDeadlines = [mergeDeadline(at: mergeEnd)]
    let ownRateDetails = mergeRateDetails(currency: "EUR")
    let existing = Booking(
        provider: .manual,
        bookingType: .hotel,
        startAt: mergeStart,
        endAt: mergeEnd,
        cancellationDeadlines: ownDeadlines,
        rateDetails: ownRateDetails,
        passengers: ownPassengers,
        guestHints: ownHints
    )
    let draft = try mergeDraft(mergeFullExtraction())

    let merged = PasteImportMerger.fillingGaps(on: existing, from: draft)

    #expect(merged.passengers == ownPassengers)
    #expect(merged.guestHints == ownHints)
    #expect(merged.cancellationDeadlines == ownDeadlines)
    #expect(merged.rateDetails == ownRateDetails)
}

@Test func pasteImportMerger_neverTouchesIdentityScheduleOrStatus() throws {
    let existing = Booking(
        provider: .booking,
        bookingType: .hotel,
        startAt: mergeStart,
        endAt: mergeEnd,
        status: .unknown,
        tripID: nil
    )
    let draft = try mergeDraft(mergeFullExtraction())

    let merged = PasteImportMerger.fillingGaps(on: existing, from: draft)

    #expect(merged.id == existing.id)
    #expect(merged.provider == .booking)
    #expect(merged.bookingType == .hotel)
    #expect(merged.startAt == mergeStart)
    #expect(merged.endAt == mergeEnd)
    #expect(merged.externalUrl == nil)
    #expect(merged.lastSyncedAt == nil)
    #expect(merged.tripID == nil)
    #expect(merged.status == .unknown)
}
