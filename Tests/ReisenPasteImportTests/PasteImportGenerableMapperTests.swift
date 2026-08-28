import Foundation
import Testing
import ReisenDomain
import ReisenPasteImport

@Test func pasteImportGenerableMapper_unknownTypeBecomesNilNotOther() {
    let dto = PasteImportBookingDTO(bookingType: "spaceship", startAtISO8601: "2026-08-28T10:00:00Z", title: "X")
    let extraction = PasteImportGenerableMapper.extraction(from: dto)
    #expect(extraction.bookingType == nil)
    #expect(extraction.startAt != nil)
}

@Test func pasteImportGenerableMapper_trainAndStart_roundTripFilterKeepsManualProvider() throws {
    let dto = PasteImportBookingDTO(bookingType: "train", startAtISO8601: "2026-08-28T10:00:00Z", title: "ICE 123")
    let extraction = PasteImportGenerableMapper.extraction(from: dto)
    let draft = try #require(PasteImportFilter.apply([extraction]).first)
    #expect(draft.asProviderDraft().provider == .manual)
    #expect(draft.bookingType == .train)
}

@Test func pasteImportGenerableMapper_parsesISO8601WithAndWithoutFractionalSeconds() throws {
    let plain = PasteImportGenerableMapper.extraction(
        from: PasteImportBookingDTO(startAtISO8601: "2026-08-28T10:00:00Z")
    )
    let fractional = PasteImportGenerableMapper.extraction(
        from: PasteImportBookingDTO(startAtISO8601: "2026-08-28T10:00:00.000Z")
    )
    #expect(plain.startAt == fractional.startAt)
    #expect(try #require(plain.startAt) == Date(timeIntervalSince1970: 1_787_911_200))
}

@Test func pasteImportGenerableMapper_unparsableDatesBecomeNil() {
    let dto = PasteImportBookingDTO(startAtISO8601: "28.08.2026", endAtISO8601: "   ")
    let extraction = PasteImportGenerableMapper.extraction(from: dto)
    #expect(extraction.startAt == nil)
    #expect(extraction.endAt == nil)
}

@Test func pasteImportGenerableMapper_blankStringsBecomeNilAndValuesAreTrimmed() {
    let dto = PasteImportBookingDTO(
        title: "   ",
        confirmationCode: " XYZ ",
        locationFrom: "\n",
        operatorName: " DB "
    )
    let extraction = PasteImportGenerableMapper.extraction(from: dto)
    #expect(extraction.title == nil)
    #expect(extraction.confirmationCode == "XYZ")
    #expect(extraction.locationFrom == nil)
    #expect(extraction.operatorName == "DB")
}

@Test func pasteImportGenerableMapper_unknownStatusBecomesNil() {
    let known = PasteImportGenerableMapper.extraction(from: PasteImportBookingDTO(status: "cancelled"))
    let unknown = PasteImportGenerableMapper.extraction(from: PasteImportBookingDTO(status: "pending"))
    #expect(known.status == .cancelled)
    #expect(unknown.status == nil)
}

@Test func pasteImportGenerableMapper_mapsScalarsAndOffsets() {
    let dto = PasteImportBookingDTO(
        bookingType: "hotel",
        externalUrl: "https://example.com/b/1",
        locationTo: "Rom",
        locationToAddress: "Via Roma 1",
        hotelCheckInMinutes: 900,
        hotelCheckOutMinutes: 660,
        hotelOffsetSeconds: 7200,
        flightDepartureOffsetSeconds: 3600,
        flightArrivalOffsetSeconds: -3600
    )
    let extraction = PasteImportGenerableMapper.extraction(from: dto)
    #expect(extraction.bookingType == .hotel)
    #expect(extraction.externalUrl == "https://example.com/b/1")
    #expect(extraction.locationTo == "Rom")
    #expect(extraction.locationToAddress == "Via Roma 1")
    #expect(extraction.hotelCheckInMinutes == 900)
    #expect(extraction.hotelCheckOutMinutes == 660)
    #expect(extraction.hotelOffsetSeconds == 7200)
    #expect(extraction.flightDepartureOffsetSeconds == 3600)
    #expect(extraction.flightArrivalOffsetSeconds == -3600)
}

@Test func pasteImportGenerableMapper_numbersPassengersByPositionWhenMissing() throws {
    let dto = PasteImportBookingDTO(
        passengers: [
            PasteImportPassengerDTO(travellerType: "adult", givenName: " Ada "),
            PasteImportPassengerDTO(passengerNumber: 7, travellerType: "spaceling", familyName: "Byron")
        ]
    )
    let extraction = PasteImportGenerableMapper.extraction(from: dto)
    #expect(extraction.passengers.count == 2)
    let first = try #require(extraction.passengers.first)
    let second = try #require(extraction.passengers.last)
    #expect(first.passengerNumber == 1)
    #expect(first.travellerType == .adult)
    #expect(first.givenName == "Ada")
    #expect(second.passengerNumber == 7)
    #expect(second.travellerType == .unknown)
    #expect(second.familyName == "Byron")
}

@Test func pasteImportGenerableMapper_mapsRateDetailsAndKeepsUnknownBoardType() throws {
    let dto = PasteImportBookingDTO(
        rateDetails: PasteImportRateDetailsDTO(
            totalPriceAmount: 499.9,
            totalPriceCurrency: " EUR ",
            roomCategory: "Doppelzimmer",
            boardType: "allInclusive",
            includedBreakfast: true,
            guestCount: 2,
            roomCount: 1
        )
    )
    let details = try #require(PasteImportGenerableMapper.extraction(from: dto).rateDetails)
    #expect(details.totalPriceAmount == 499.9)
    #expect(details.totalPriceCurrency == "EUR")
    #expect(details.roomCategory == "Doppelzimmer")
    #expect(details.boardType == .unknown)
    #expect(details.includedBreakfast == true)
    #expect(details.guestCount == 2)
    #expect(details.roomCount == 1)
}

@Test func pasteImportGenerableMapper_mapsKnownBoardType() throws {
    let dto = PasteImportBookingDTO(rateDetails: PasteImportRateDetailsDTO(boardType: "halfBoard"))
    let details = try #require(PasteImportGenerableMapper.extraction(from: dto).rateDetails)
    #expect(details.boardType == .halfBoard)
}

@Test func pasteImportGenerableMapper_mapsDeadline() throws {
    let dto = PasteImportBookingDTO(
        deadlines: [
            PasteImportDeadlineDTO(
                deadlineAtISO8601: "2026-08-20T12:00:00Z",
                policyText: " Kostenlos bis 20.08. ",
                isFreeCancellation: true,
                cancellationFeeAmount: 0
            )
        ]
    )
    let deadline = try #require(PasteImportGenerableMapper.extraction(from: dto).deadlines.first)
    #expect(deadline.deadlineAt == Date(timeIntervalSince1970: 1_787_227_200))
    #expect(deadline.policyText == "Kostenlos bis 20.08.")
    #expect(deadline.isFreeCancellation == true)
    #expect(deadline.cancellationFeeAmount == 0)
}

@Test func pasteImportGenerableMapper_skipsDeadlineWithoutDateAndKeepsTheOthers() throws {
    let dto = PasteImportBookingDTO(deadlines: [
        PasteImportDeadlineDTO(policyText: "irgendwann"),
        PasteImportDeadlineDTO(deadlineAtISO8601: "2026-08-20T12:00:00Z", policyText: "bis 20.08.")
    ])
    let deadlines = PasteImportGenerableMapper.extraction(from: dto).deadlines
    #expect(deadlines.count == 1)
    #expect(try #require(deadlines.first).policyText == "bis 20.08.")
}

@Test func pasteImportGenerableMapper_mapsGuestHintWithStableSourceKey() throws {
    let dto = PasteImportBookingDTO(
        guestHints: [PasteImportGuestHintDTO(title: " Bettwäsche ", detail: " Selbst mitbringen ")]
    )
    let hint = try #require(PasteImportGenerableMapper.extraction(from: dto).guestHints.first)
    #expect(hint.category == .preTravelImportant)
    #expect(hint.title == "Bettwäsche")
    #expect(hint.detail == "Selbst mitbringen")
    #expect(hint.sourceKey == "pasteImport:hint:Bettwäsche")
}

@Test func pasteImportGenerableMapper_skipsIncompleteGuestHintAndKeepsTheOthers() throws {
    let dto = PasteImportBookingDTO(guestHints: [
        PasteImportGuestHintDTO(title: "Bettwäsche"),
        PasteImportGuestHintDTO(title: "Kurtaxe", detail: "Vor Ort zahlen")
    ])
    let hints = PasteImportGenerableMapper.extraction(from: dto).guestHints
    #expect(hints.count == 1)
    #expect(try #require(hints.first).title == "Kurtaxe")
}

/// Ein halb erkanntes Detail darf die erkannte Buchung nicht mitreißen — sonst meldete der Import
/// „nichts gefunden“, obwohl der Flug vollständig dastand.
@Test func pasteImportGenerableMapper_keepsBookingDespiteIncompleteNestedValues() throws {
    let payload = PasteImportPayloadDTO(bookings: [
        PasteImportBookingDTO(
            bookingType: "flight",
            startAtISO8601: "2026-08-28T10:00:00Z",
            title: "LH 400",
            guestHints: [PasteImportGuestHintDTO(title: "Bettwäsche")],
            deadlines: [PasteImportDeadlineDTO(policyText: "irgendwann")]
        )
    ])
    let extraction = try #require(PasteImportGenerableMapper.extractions(from: payload).first)
    #expect(extraction.title == "LH 400")
    #expect(extraction.bookingType == .flight)
    #expect(extraction.guestHints.isEmpty)
    #expect(extraction.deadlines.isEmpty)
}

@Test func pasteImportGenerableMapper_mapsWholePayloadInOrder() throws {
    let payload = PasteImportPayloadDTO(bookings: [
        PasteImportBookingDTO(bookingType: "train", startAtISO8601: "2026-08-28T10:00:00Z", title: "ICE 123"),
        PasteImportBookingDTO(bookingType: "hotel", startAtISO8601: "2026-08-28T18:00:00Z", title: "Hotel Roma")
    ])
    let extractions = PasteImportGenerableMapper.extractions(from: payload)
    #expect(extractions.count == 2)
    #expect(try #require(extractions.first).bookingType == .train)
    #expect(try #require(extractions.last).title == "Hotel Roma")
}
