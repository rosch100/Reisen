import Foundation
import Testing
import ReisenDomain
import ReisenPasteImport

@Test func pasteImportGenerableMapper_unknownTypeBecomesNilNotOther() throws {
    let dto = PasteImportBookingDTO(bookingType: "spaceship", startAtISO8601: "2026-08-28T10:00:00Z", title: "X")
    let extraction = try PasteImportGenerableMapper.extraction(from: dto)
    #expect(extraction.bookingType == nil)
    #expect(extraction.startAt != nil)
}

@Test func pasteImportGenerableMapper_trainAndStart_roundTripFilterKeepsManualProvider() throws {
    let dto = PasteImportBookingDTO(bookingType: "train", startAtISO8601: "2026-08-28T10:00:00Z", title: "ICE 123")
    let extraction = try PasteImportGenerableMapper.extraction(from: dto)
    let draft = try #require(PasteImportFilter.apply([extraction]).first)
    #expect(draft.asProviderDraft().provider == .manual)
    #expect(draft.bookingType == .train)
}

@Test func pasteImportGenerableMapper_parsesISO8601WithAndWithoutFractionalSeconds() throws {
    let plain = try PasteImportGenerableMapper.extraction(
        from: PasteImportBookingDTO(startAtISO8601: "2026-08-28T10:00:00Z")
    )
    let fractional = try PasteImportGenerableMapper.extraction(
        from: PasteImportBookingDTO(startAtISO8601: "2026-08-28T10:00:00.000Z")
    )
    #expect(plain.startAt == fractional.startAt)
    #expect(try #require(plain.startAt) == Date(timeIntervalSince1970: 1_787_911_200))
}

@Test func pasteImportGenerableMapper_unparsableDatesBecomeNil() throws {
    let dto = PasteImportBookingDTO(startAtISO8601: "28.08.2026", endAtISO8601: "   ")
    let extraction = try PasteImportGenerableMapper.extraction(from: dto)
    #expect(extraction.startAt == nil)
    #expect(extraction.endAt == nil)
}

@Test func pasteImportGenerableMapper_blankStringsBecomeNilAndValuesAreTrimmed() throws {
    let dto = PasteImportBookingDTO(
        title: "   ",
        confirmationCode: " XYZ ",
        locationFrom: "\n",
        operatorName: " DB "
    )
    let extraction = try PasteImportGenerableMapper.extraction(from: dto)
    #expect(extraction.title == nil)
    #expect(extraction.confirmationCode == "XYZ")
    #expect(extraction.locationFrom == nil)
    #expect(extraction.operatorName == "DB")
}

@Test func pasteImportGenerableMapper_unknownStatusBecomesNil() throws {
    let known = try PasteImportGenerableMapper.extraction(from: PasteImportBookingDTO(status: "cancelled"))
    let unknown = try PasteImportGenerableMapper.extraction(from: PasteImportBookingDTO(status: "pending"))
    #expect(known.status == .cancelled)
    #expect(unknown.status == nil)
}

@Test func pasteImportGenerableMapper_mapsScalarsAndOffsets() throws {
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
    let extraction = try PasteImportGenerableMapper.extraction(from: dto)
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
    let extraction = try PasteImportGenerableMapper.extraction(from: dto)
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
    let details = try #require(try PasteImportGenerableMapper.extraction(from: dto).rateDetails)
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
    let details = try #require(try PasteImportGenerableMapper.extraction(from: dto).rateDetails)
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
    let deadline = try #require(try PasteImportGenerableMapper.extraction(from: dto).deadlines.first)
    #expect(deadline.deadlineAt == Date(timeIntervalSince1970: 1_787_227_200))
    #expect(deadline.policyText == "Kostenlos bis 20.08.")
    #expect(deadline.isFreeCancellation == true)
    #expect(deadline.cancellationFeeAmount == 0)
}

@Test func pasteImportGenerableMapper_deadlineWithoutDateThrows() {
    let dto = PasteImportBookingDTO(deadlines: [PasteImportDeadlineDTO(policyText: "irgendwann")])
    #expect(throws: PasteImportMapperError.invalidDeadlineDate(nil)) {
        try PasteImportGenerableMapper.extraction(from: dto)
    }
}

@Test func pasteImportGenerableMapper_mapsGuestHintWithStableSourceKey() throws {
    let dto = PasteImportBookingDTO(
        guestHints: [PasteImportGuestHintDTO(title: " Bettwäsche ", detail: " Selbst mitbringen ")]
    )
    let hint = try #require(try PasteImportGenerableMapper.extraction(from: dto).guestHints.first)
    #expect(hint.category == .preTravelImportant)
    #expect(hint.title == "Bettwäsche")
    #expect(hint.detail == "Selbst mitbringen")
    #expect(hint.sourceKey == "pasteImport:hint:Bettwäsche")
}

@Test func pasteImportGenerableMapper_guestHintWithoutDetailThrows() {
    let dto = PasteImportBookingDTO(guestHints: [PasteImportGuestHintDTO(title: "Bettwäsche")])
    #expect(throws: PasteImportMapperError.incompleteGuestHint) {
        try PasteImportGenerableMapper.extraction(from: dto)
    }
}

@Test func pasteImportGenerableMapper_mapsWholePayloadInOrder() throws {
    let payload = PasteImportPayloadDTO(bookings: [
        PasteImportBookingDTO(bookingType: "train", startAtISO8601: "2026-08-28T10:00:00Z", title: "ICE 123"),
        PasteImportBookingDTO(bookingType: "hotel", startAtISO8601: "2026-08-28T18:00:00Z", title: "Hotel Roma")
    ])
    let extractions = try PasteImportGenerableMapper.extractions(from: payload)
    #expect(extractions.count == 2)
    #expect(try #require(extractions.first).bookingType == .train)
    #expect(try #require(extractions.last).title == "Hotel Roma")
}
