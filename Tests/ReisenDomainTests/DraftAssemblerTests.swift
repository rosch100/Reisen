import Foundation
import Testing
import ReisenDomain

@Test func bookingStatusParse_confirmedKeywords() {
    #expect(BookingStatus.parse("CONFIRMED") == .confirmed)
    #expect(BookingStatus.parse("active") == .confirmed)
    #expect(BookingStatus.parse("ISSUED") == .confirmed)
    #expect(BookingStatus.parse("ETICKET_PUBLISHED") == .confirmed)
    #expect(BookingStatus.parse("CONTRACT") == .confirmed)
    #expect(BookingStatus.parse("upcoming") == .confirmed)
    #expect(BookingStatus.parse("ACCEPT") == .confirmed)
    #expect(BookingStatus.parse("accepted") == .confirmed)
    #expect(BookingStatus.parse("voucher issued") == .confirmed)
    #expect(BookingStatus.parse("e-ticket issued") == .confirmed)
}

@Test func bookingStatusParse_cancelledKeywords() {
    #expect(BookingStatus.parse("CANCELLED") == .cancelled)
    #expect(BookingStatus.parse("canceled") == .cancelled)
    #expect(BookingStatus.parse("Reservation cancelled") == .cancelled)
    #expect(BookingStatus.parse("REFUNDED") == .cancelled)
    #expect(BookingStatus.parse("terminated") == .cancelled)
    #expect(BookingStatus.parse("BOOKING_CANCELLED") == .cancelled)
    #expect(BookingStatus.parse("RETAINED") == .cancelled)
    #expect(BookingStatus.parse("FINAL_RET") == .cancelled)
    #expect(BookingStatus.parse("DIDNOTBUY") == .cancelled)
    #expect(BookingStatus.parse("VOID") == .cancelled)
    #expect(BookingStatus.parse("Storniert") == .cancelled)
    #expect(BookingStatus.parse("booking canceled") == .cancelled)
}

@Test func bookingStatusParse_doesNotTreatRefundableOrNonCancelAsCancelled() {
    #expect(BookingStatus.parse("Refundable") == .unknown)
    #expect(BookingStatus.parse("Non-cancellable") == .unknown)
    #expect(BookingStatus.parse("CANCELLABLE") == .unknown)
    #expect(BookingStatus.parse("PENDING_CANCELLATION_HOLD") == .unknown)
    #expect(BookingStatus.parse("CANCELLATION_AVAILABLE") == .unknown)
    #expect(BookingStatus.parse("Stornierungsrichtlinie Bis 1. August") == .unknown)
    #expect(BookingStatus.parse(nil) == .unknown)
}

@Test func bookingStatusParse_partsCancelledWinsOverConfirmed() {
    #expect(BookingStatus.parse(parts: ["CONTRACT", "CANCELLED"]) == .cancelled)
    #expect(BookingStatus.parse(parts: ["CONTRACT", "CANCELLABLE"]) == .confirmed)
}

@Test func bookingStatusParseToken_exactGraphQLTokensOnly() {
    #expect(BookingStatus.parseToken("CONFIRMED") == .confirmed)
    #expect(BookingStatus.parseToken("ACCEPT") == .confirmed)
    #expect(BookingStatus.parseToken("accepted") == .confirmed)
    #expect(BookingStatus.parseToken("CANCELLED") == .cancelled)
    #expect(BookingStatus.parseToken("CANCELED") == .cancelled)
    #expect(BookingStatus.parseToken("Reservation cancelled") == .unknown)
    #expect(BookingStatus.parseToken("PENDING_CANCELLATION_HOLD") == .unknown)
    #expect(BookingStatus.parseToken("CANCELLABLE") == .unknown)
    #expect(BookingStatus.parseToken(nil) == .unknown)
}

@Test func travellerTypeParse_tokensAndLabels() {
    #expect(TravellerType.parse("ADULT") == .adult)
    #expect(TravellerType.parse("adt") == .adult)
    #expect(TravellerType.parse("child") == .child)
    #expect(TravellerType.parse("youth") == .child)
    #expect(TravellerType.parse("CHD") == .child)
    #expect(TravellerType.parse("infant") == .infant)
    #expect(TravellerType.parse("baby") == .infant)
    #expect(TravellerType.parse("inf") == .infant)
    #expect(TravellerType.parse(nil) == .unknown)
}

@Test func baggageTypeParse_providerLuggageTypes() {
    #expect(BaggageType.parse("CHECKED_IN") == .checkedBag)
    #expect(BaggageType.parse("CHECKED_BAG") == .checkedBag)
    #expect(BaggageType.parse("checked-bag-priority") == .checkedBag)
    #expect(BaggageType.parse("HAND") == .cabinBag)
    #expect(BaggageType.parse("CABIN_BAG") == .cabinBag)
    #expect(BaggageType.parse("carry-on-bag") == .cabinBag)
    #expect(BaggageType.parse("carry-on-small-bag") == .personalItem)
    #expect(BaggageType.parse("PERSONAL_ITEM") == .personalItem)
    #expect(BaggageType.parse(nil) == .unknown)
}

@Test func bookingBoardTypeParse_rawValues() {
    #expect(BookingBoardType.parse("breakfastIncluded") == .breakfastIncluded)
    #expect(BookingBoardType.parse("BB") == .breakfastIncluded)
    #expect(BookingBoardType.parse("HB") == .halfBoard)
    #expect(BookingBoardType.parse("FB") == .fullBoard)
    #expect(BookingBoardType.parse("RO") == .roomOnly)
    #expect(BookingBoardType.parse("") == .unknown)
    #expect(BookingBoardType.parse(nil) == .unknown)
}

@Test func bookingBoardTypeParse_breakfastIncludedFlag() {
    #expect(BookingBoardType.parse(breakfastIncluded: true) == .breakfastIncluded)
    #expect(BookingBoardType.parse(breakfastIncluded: false) == .roomOnly)
    #expect(BookingBoardType.parse(breakfastIncluded: nil) == .unknown)
    #expect(BookingBoardType.unknown.includedBreakfast == nil)
    #expect(BookingBoardType.breakfastIncluded.includedBreakfast == true)
    #expect(BookingBoardType.roomOnly.includedBreakfast == false)
    #expect(BookingBoardType.halfBoard.includedBreakfast == false)
    #expect(BookingBoardType.fullBoard.includedBreakfast == false)
}

@Test func placeLabel_combinesCityAndIATA() {
    #expect(PlaceLabel.make(city: "Berlin", iata: "BER") == "Berlin (BER)")
    #expect(PlaceLabel.make(city: "Berlin", iata: nil) == "Berlin")
    #expect(PlaceLabel.make(city: nil, iata: "BER") == "BER")
    #expect(PlaceLabel.make(city: "  ", iata: nil) == nil)
}

@Test func placeLabel_routeJoinsBothCities() {
    #expect(PlaceLabel.route(from: "Berlin", to: "München") == "Berlin → München")
    #expect(PlaceLabel.route(from: "Berlin", to: nil) == nil)
    #expect(PlaceLabel.route(from: "  ", to: "München") == nil)
}

@Test func bookingStatus_joinedRawConcatenatesTokens() {
    #expect(BookingStatus.joinedRaw("CONFIRMED", "ACTIVE") == "CONFIRMED\nACTIVE")
    #expect(BookingStatus.joinedRaw(nil, "CONFIRMED") == "CONFIRMED")
    #expect(BookingStatus.joinedRaw(nil, nil) == nil)
    #expect(BookingStatus.joinedRaw(["CONFIRMED", nil, "ACTIVE"]) == "CONFIRMED\nACTIVE")
    #expect(BookingStatus.parse(BookingStatus.joinedRaw("CONFIRMED", "CANCELLED")) == .cancelled)
}

@Test func nonEmpty_trimsAndDropsBlank() {
    #expect(NonEmpty.string("  Berlin  ") == "Berlin")
    #expect(NonEmpty.string("  ") == nil)
    #expect(NonEmpty.string(nil) == nil)
    #expect(NonEmpty.first(nil, "  ", "Berlin", "München") == "Berlin")
    #expect(NonEmpty.first(nil, "  ") == nil)
    #expect(NonEmpty.combine("10115", "Berlin") { zip, city in "\(zip) \(city)" } == "10115 Berlin")
    #expect(NonEmpty.combine("Berlin", nil) { city, iata in "\(city) (\(iata))" } == "Berlin")
}

@Test func postalAddress_joinsPresentParts() {
    #expect(
        PostalAddress.lines(
            street: "Street 1",
            postalCode: "10115",
            city: "Berlin",
            country: "DE"
        ) == "Street 1, 10115 Berlin, DE"
    )
    #expect(PostalAddress.cityLine(city: "Berlin", postalCode: nil) == "Berlin")
    #expect(PostalAddress.lines(street: "  ", postalCode: nil, city: nil, country: nil) == nil)
}

@Test func bookingIdentityKey_prefersURLThenConfirmation() {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    #expect(BookingIdentityKey.make(externalUrl: "https://x", confirmationCode: "A", startAt: start) == "url:https://x")
    #expect(
        BookingIdentityKey.make(externalUrl: nil, confirmationCode: "A", startAt: start)
            == "conf:A|start:1700000000.0"
    )
    #expect(BookingIdentityKey.make(externalUrl: nil, confirmationCode: nil, startAt: start) == nil)
}

@Test func cancellationDeadlines_firstHotelOffsetAndLatestFree() {
    let earlier = CancellationDeadline(
        deadlineAt: Date(timeIntervalSince1970: 1),
        isFreeCancellation: true,
        hotelOffsetSeconds: 3600
    )
    let laterFree = CancellationDeadline(
        deadlineAt: Date(timeIntervalSince1970: 2),
        isFreeCancellation: true,
        hotelOffsetSeconds: 7200
    )
    let paid = CancellationDeadline(
        deadlineAt: Date(timeIntervalSince1970: 3),
        isFreeCancellation: false
    )
    let deadlines = [earlier, paid, laterFree]
    #expect(deadlines.firstHotelOffsetSeconds == 3600)
    #expect(deadlines.preferringLatestFree == [laterFree])
    let duplicatePaid = CancellationDeadline(
        deadlineAt: Date(timeIntervalSince1970: 3),
        isFreeCancellation: false
    )
    #expect([paid, duplicatePaid].deduped.count == 1)
    #expect([paid, duplicatePaid].deduped.first?.deadlineAt == paid.deadlineAt)
}

@Test func cancellationDeadlines_combiningKeepsExistingFreeAndAddsRefundFee() {
    let existingFree = CancellationDeadline(
        deadlineAt: Date(timeIntervalSince1970: 20),
        policyText: "Itinerary free",
        isFreeCancellation: true
    )
    let refundFree = CancellationDeadline(
        deadlineAt: Date(timeIntervalSince1970: 10),
        policyText: "Refund free",
        isFreeCancellation: true
    )
    let refundFee = CancellationDeadline(
        deadlineAt: Date(timeIntervalSince1970: 30),
        policyText: "Full charge",
        isFreeCancellation: false,
        cancellationFeeAmount: 12.5
    )
    let merged = [existingFree].combining(refund: [refundFree, refundFee])
    #expect(merged.count == 2)
    #expect(merged.contains(existingFree))
    #expect(merged.contains(refundFee))
    #expect(!merged.contains(refundFree))
}

@Test func isoDateTime_offsetSeconds_zuluIsZeroMissingStaysNil() {
    #expect(ISODateTime.offsetSeconds(from: "2026-08-01T15:00:00+02:00") == 2 * 3600)
    #expect(ISODateTime.offsetSeconds(from: "2026-08-01T15:00:00Z") == 0)
    #expect(ISODateTime.offsetSeconds(from: "2026-08-01T15:00:00.000Z") == 0)
    #expect(ISODateTime.offsetSeconds(from: "2026-08-01T15:00:00") == nil)
    #expect(ISODateTime.offsetSeconds(from: "2026-08-01") == nil)
    #expect(ISODateTime.offsetSeconds(from: "+0800") == 8 * 3600)
    #expect(ISODateTime.offsetSeconds(from: "-0530") == -(5 * 3600 + 30 * 60))
}

@Test func isoDateTime_parseInstant_rejectsDayOnly() {
    let instant = ISODateTime.parseInstant("2026-08-01T15:00:00Z")
    #expect(instant == ISODateTime.parse("2026-08-01T15:00:00Z"))
    #expect(ISODateTime.parseInstant("2026-08-01T15:00:00.123Z") != nil)
    #expect(ISODateTime.parseInstant("2026-08-01") == nil)
    #expect(ISODateTime.parseInstant("2026-08-01T15:00:00") == nil)
    #expect(ISODateTime.parse("2026-08-01") != nil)
    #expect(ISODateTime.parse("  2026-08-01  ") != nil)
}

@Test func isoDateTime_parseInstant_rfc822OffsetWithoutColon() {
    let hotel = ISODateTime.parseInstant("2026-08-12T21:59:59+0800")
    let utc = ISODateTime.parseInstant("2026-08-12T13:59:59Z")
    #expect(hotel == utc)
    #expect(ISODateTime.parseInstant("2026-08-12T13:59:59+0000") == utc)
}

@Test func isoDateTime_parseWallClockUTC_withoutOffset() throws {
    let tFormat = ISODateTime.parseWallClockUTC("2026-08-01T22:00:00")
    let spaceFormat = ISODateTime.parseWallClockUTC("2026-08-01 22:00:00")
    #expect(tFormat == spaceFormat)
    #expect(tFormat != nil)
    #expect(ISODateTime.parseInstant("2026-08-01T22:00:00") == nil)
    #expect(ISODateTime.parseWallClockUTC("2026-08-01") == nil)
    #expect(ISODateTime.parseWallClockUTC("  ") == nil)

    let stored = try #require(ISODateTime.wallClockStorage(fromISO: "2026-08-01T22:00:00"))
    #expect(stored.wallClockAsUTC == tFormat)
    #expect(stored.offsetSeconds == nil)
}

@Test func clockTime_minutesFromHHMM() {
    #expect(ClockTime.minutes(hours: 14, minute: 0) == 14 * 60)
    #expect(ClockTime.minutes(hours: 0, minute: 0) == 0)
    #expect(ClockTime.minutes(hours: 23, minute: 59) == 23 * 60 + 59)
    #expect(ClockTime.minutes(hours: 24, minute: 0) == nil)
    #expect(ClockTime.minutes(hours: 12, minute: 60) == nil)
    #expect(ClockTime.minutes(fromHHMM: "14:00") == 14 * 60)
    #expect(ClockTime.minutes(fromHHMM: "9:00") == 9 * 60)
    #expect(ClockTime.minutes(fromHHMM: " 23:00 ") == 23 * 60)
    #expect(ClockTime.minutes(fromHHMM: "14:00-23:59") == nil)
    #expect(ClockTime.minutes(fromHHMM: "25:00") == nil)
    #expect(ClockTime.minutes(fromHHMM: nil) == nil)
    #expect(ClockTime.minutes(fromHHMM: "  ") == nil)
}

@Test func isoDateTime_dateOnly_omitsMissingOffset() throws {
    let withOffset = try #require(ISODateTime.dateOnly(fromISO: "2026-08-01T15:00:00+02:00"))
    #expect(withOffset.offsetSeconds == 2 * 3600)

    let zulu = try #require(ISODateTime.dateOnly(fromISO: "2026-08-01T15:00:00Z"))
    #expect(zulu.offsetSeconds == 0)

    let dateOnly = try #require(ISODateTime.dateOnly(fromISO: "2026-08-01"))
    #expect(dateOnly.offsetSeconds == nil)
}

@Test func providerCatalog_dedupedByExternalURLKeepsLastPerURL() {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let end = Date(timeIntervalSince1970: 1_700_086_400)
    let first = ProviderBookingDraft(
        provider: .opodo,
        bookingType: .hotel,
        title: "first",
        externalUrl: "https://opodo.example/a",
        startAt: start,
        endAt: end
    )
    let last = ProviderBookingDraft(
        provider: .opodo,
        bookingType: .hotel,
        title: "last",
        externalUrl: "https://opodo.example/a",
        startAt: start,
        endAt: end
    )
    let other = ProviderBookingDraft(
        provider: .opodo,
        bookingType: .flight,
        title: "other",
        externalUrl: "https://opodo.example/b",
        startAt: Date(timeIntervalSince1970: 1_699_000_000),
        endAt: end
    )
    let withoutURL = ProviderBookingDraft(
        provider: .opodo,
        bookingType: .hotel,
        title: "dropped",
        startAt: start,
        endAt: end
    )
    let catalog = ProviderCatalog(bookings: [first, last, other, withoutURL]).dedupedByExternalURL()
    #expect(Set(catalog.bookings.compactMap(\.title)) == ["last", "other"])
    #expect(catalog.bookings.map(\.startAt) == catalog.bookings.map(\.startAt).sorted())
}

@Test func temporalFact_pair_hotelUsesHotelDay_flightUsesInstant() {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let end = Date(timeIntervalSince1970: 1_700_086_400)
    let hotel = TemporalFact.pair(
        bookingType: .hotel,
        start: start,
        end: end,
        hotelOffsetSeconds: 3600
    )
    #expect(hotel.start == .hotelDay(start, offsetSeconds: 3600))
    #expect(hotel.end == .hotelDay(end, offsetSeconds: 3600))

    let flight = TemporalFact.pair(bookingType: .flight, start: start, end: end, hotelOffsetSeconds: 3600)
    #expect(flight.start == .instant(start))
    #expect(flight.end == .instant(end))
}

@Test func bookingDateWindow_hotelISO_withoutTimezone_hasNilOffset() throws {
    let window = BookingDateWindow.resolve(
        type: .hotel,
        start: .iso("2026-08-01"),
        end: .iso("2026-08-05")
    )
    let resolved = try #require(window)
    #expect(resolved.hotelOffsetSeconds == nil)
}

@Test func draftAssembler_requireDraft_throwsWhenDatesMissing() {
    let facts = ProviderBookingFacts(
        provider: .booking,
        bookingType: .hotel,
        title: "Hotel"
    )
    #expect(throws: DraftAssembler.Error.missingDateWindow) {
        _ = try DraftAssembler.requireDraft(from: facts)
    }
}

@Test func draftAssembler_requireDraft_throwsWhenDroppedFromCatalog() {
    let facts = ProviderBookingFacts(
        provider: .getYourGuide,
        bookingType: .activity,
        start: .instant(Date(timeIntervalSince1970: 10)),
        end: .instant(Date(timeIntervalSince1970: 20)),
        title: "Tour",
        statusRaw: "done"
    )
    #expect(throws: DraftAssembler.Error.droppedFromCatalog) {
        _ = try DraftAssembler.requireDraft(from: facts)
    }
}

@Test func bookingDateWindow_hotelISO_usesDateOnly() throws {
    let window = BookingDateWindow.resolve(
        type: .hotel,
        start: .iso("2026-08-01T15:00:00+02:00"),
        end: .iso("2026-08-05T11:00:00+02:00")
    )
    let resolved = try #require(window)
    #expect(HotelStayDate.format(resolved.startAt, dateFormat: "yyyy-MM-dd") == "2026-08-01")
    #expect(HotelStayDate.format(resolved.endAt, dateFormat: "yyyy-MM-dd") == "2026-08-05")
    #expect(resolved.hotelOffsetSeconds == 2 * 3600)
    #expect(resolved.flightDepartureOffsetSeconds == nil)
}

@Test func bookingDateWindow_flightISO_storesWallClockAsUTC() throws {
    let window = BookingDateWindow.resolve(
        type: .flight,
        start: .iso("2026-08-01T09:30:00+02:00"),
        end: .iso("2026-08-01T11:45:00+02:00")
    )
    let resolved = try #require(window)
    #expect(resolved.flightDepartureOffsetSeconds == 2 * 3600)
    #expect(resolved.flightArrivalOffsetSeconds == 2 * 3600)
    let startParts = Calendar(identifier: .gregorian).dateComponents(
        in: HotelStayDate.timeZone,
        from: resolved.startAt
    )
    #expect(startParts.hour == 9)
    #expect(startParts.minute == 30)
}

@Test func bookingDateWindow_hotelParsed_canonicalizesCalendarDay() {
    let start = Date(timeIntervalSince1970: 10)
    let end = Date(timeIntervalSince1970: 20)
    let window = BookingDateWindow.resolve(
        type: .hotel,
        start: .instant(start),
        end: .instant(end)
    )
    #expect(window?.startAt == HotelStayDate.calendarDay(fromParsed: start))
    #expect(window?.endAt == HotelStayDate.calendarDay(fromParsed: end))
    #expect(window?.hotelOffsetSeconds == nil)
}

@Test func bookingDateWindow_hotelParsed_usesOffsetCivilDay() {
    let start = Date(timeIntervalSince1970: 1_775_340_000) // 2026-04-04T22:00:00Z
    let end = Date(timeIntervalSince1970: 1_775_426_400) // 2026-04-05T22:00:00Z
    let window = BookingDateWindow.resolve(
        type: .hotel,
        start: .hotelDay(start, offsetSeconds: 2 * 3600),
        end: .hotelDay(end, offsetSeconds: nil)
    )
    #expect(window?.startAt == HotelStayDate.dateOnly(year: 2026, month: 4, day: 5))
    #expect(window?.endAt == HotelStayDate.dateOnly(year: 2026, month: 4, day: 6))
    #expect(window?.hotelOffsetSeconds == 2 * 3600)
}

@Test func bookingDateWindow_hotelParsed_usesEndOffsetWhenPresent() {
    let start = Date(timeIntervalSince1970: 1_775_340_000) // 2026-04-04T22:00:00Z
    let end = Date(timeIntervalSince1970: 1_775_404_800) // 2026-04-05T16:00:00Z
    let window = BookingDateWindow.resolve(
        type: .hotel,
        start: .hotelDay(start, offsetSeconds: 2 * 3600),
        end: .hotelDay(end, offsetSeconds: 9 * 3600)
    )
    #expect(window?.startAt == HotelStayDate.dateOnly(year: 2026, month: 4, day: 5))
    #expect(window?.endAt == HotelStayDate.dateOnly(year: 2026, month: 4, day: 6))
    #expect(window?.hotelOffsetSeconds == 2 * 3600)
}

@Test func bookingDateWindow_hotelInstantMatchesHotelDayWithoutOffset() {
    let start = Date(timeIntervalSince1970: 10)
    let end = Date(timeIntervalSince1970: 20)
    let fromInstant = BookingDateWindow.resolve(
        type: .hotel,
        start: .instant(start),
        end: .instant(end)
    )
    let fromHotelDay = BookingDateWindow.resolve(
        type: .hotel,
        start: .hotelDay(start, offsetSeconds: nil),
        end: .hotelDay(end, offsetSeconds: nil)
    )
    #expect(fromInstant == fromHotelDay)
}

@Test func draftAssembler_hotelISO_buildsDraft() throws {
    let facts = ProviderBookingFacts(
        provider: .booking,
        bookingType: .hotel,
        start: .iso("2026-08-01T15:00:00+02:00"),
        end: .iso("2026-08-05T11:00:00+02:00"),
        title: "Hotel",
        externalUrl: "https://secure.booking.com/confirmation",
        statusRaw: "CONFIRMED"
    )
    let draft = try #require(DraftAssembler.draft(from: facts))
    #expect(draft.provider == .booking)
    #expect(draft.status == .confirmed)
    #expect(draft.hotelOffsetSeconds == 2 * 3600)
    #expect(HotelStayDate.format(draft.startAt, dateFormat: "yyyy-MM-dd") == "2026-08-01")
}

@Test func draftAssembler_missingDates_returnsNil() {
    let facts = ProviderBookingFacts(
        provider: .booking,
        bookingType: .hotel,
        title: "Hotel"
    )
    #expect(DraftAssembler.draft(from: facts) == nil)
}

@Test func draftAssembler_instantFacts_buildDraftWithoutCrash() throws {
    let start = Date(timeIntervalSince1970: 10)
    let end = Date(timeIntervalSince1970: 20)
    let draft = try #require(
        DraftAssembler.draft(
            from: ProviderBookingFacts(
                provider: .check24,
                bookingType: .hotel,
                start: .instant(start),
                end: .instant(end),
                title: "Hotel"
            )
        )
    )
    #expect(draft.startAt == HotelStayDate.calendarDay(fromParsed: start))
    #expect(draft.endAt == HotelStayDate.calendarDay(fromParsed: end))
}

@Test func draftAssembler_doesNotCopyDeadlineOffsetAsStayOffset() throws {
    let start = Date(timeIntervalSince1970: 10)
    let end = Date(timeIntervalSince1970: 20)
    let draft = try #require(
        DraftAssembler.draft(
            from: ProviderBookingFacts(
                provider: .check24,
                bookingType: .flight,
                start: .instant(start),
                end: .instant(end),
                deadlines: [
                    CancellationDeadline(
                        deadlineAt: end,
                        hotelOffsetSeconds: 2 * 3600
                    )
                ]
            )
        )
    )
    #expect(draft.hotelOffsetSeconds == nil)
}

@Test func draftAssembler_ignoresExplicitStayOffsetOnFlight() throws {
    let start = Date(timeIntervalSince1970: 10)
    let end = Date(timeIntervalSince1970: 20)
    let draft = try #require(
        DraftAssembler.draft(
            from: ProviderBookingFacts(
                provider: .traveloka,
                bookingType: .flight,
                start: .instant(start),
                end: .instant(end),
                hotelOffsetSeconds: 7 * 3600
            )
        )
    )
    #expect(draft.hotelOffsetSeconds == nil)
}

@Test func draftAssembler_ignoresExplicitStayOffsetOnActivity() throws {
    let start = Date(timeIntervalSince1970: 10)
    let end = Date(timeIntervalSince1970: 20)
    let draft = try #require(
        DraftAssembler.draft(
            from: ProviderBookingFacts(
                provider: .traveloka,
                bookingType: .activity,
                start: .instant(start),
                end: .instant(end),
                hotelOffsetSeconds: 7 * 3600
            )
        )
    )
    #expect(draft.hotelOffsetSeconds == nil)
}

@Test func draftAssembler_usesProviderParsedStatus() throws {
    #expect(
        DraftAssembler.draft(
            from: ProviderBookingFacts(
                provider: .airbnb,
                bookingType: .hotel,
                start: .instant(Date(timeIntervalSince1970: 10)),
                end: .instant(Date(timeIntervalSince1970: 20)),
                statusRaw: "Reservation cancelled"
            )
        ) == nil
    )

    let unknownToken = try #require(
        DraftAssembler.draft(
            from: ProviderBookingFacts(
                provider: .booking,
                bookingType: .hotel,
                start: .instant(Date(timeIntervalSince1970: 10)),
                end: .instant(Date(timeIntervalSince1970: 20)),
                statusRaw: "PENDING_CANCELLATION_HOLD"
            )
        )
    )
    #expect(unknownToken.status == .unknown)
}

@Test func draftAssembler_enrichment_cancelledDropsDeadlines() {
    let paid = CancellationDeadline(
        deadlineAt: Date(timeIntervalSince1970: 1_700_000_000),
        isFreeCancellation: false
    )
    let enrichment = DraftAssembler.enrichment(
        from: ProviderBookingFacts(
            provider: .opodo,
            bookingType: .hotel,
            statusRaw: "CANCELLED",
            deadlines: [paid],
            hotelOffsetSeconds: 3600
        )
    )
    #expect(enrichment.status == .cancelled)
    #expect(enrichment.deadlines.isEmpty)
    #expect(enrichment.hotelOffsetSeconds == nil)

    var draft = catalogHotelDraft(provider: .opodo, externalUrl: "https://www.opodo.de/booking")
    draft.hotelOffsetSeconds = 3600
    draft.apply(enrichment)
    #expect(draft.status == .cancelled)
    #expect(draft.deadlines.isEmpty)
    #expect(draft.hotelOffsetSeconds == nil)
}

@Test func draftApply_emptyConfirmedEnrichmentKeepsCatalogDeadlines() {
    var draft = catalogHotelDraft(provider: .opodo, externalUrl: "https://www.opodo.de/booking")
    let catalogDeadlines = draft.deadlines
    draft.hotelOffsetSeconds = 3600
    draft.apply(ProviderBookingEnrichment(status: .confirmed))
    #expect(draft.deadlines == catalogDeadlines)
    #expect(draft.hotelOffsetSeconds == 3600)
}

@Test func catalogListing_dropsCancelledEndedAndDone() {
    #expect(CatalogListing.shouldDrop("cancelled"))
    #expect(CatalogListing.shouldDrop("ENDED"))
    #expect(CatalogListing.shouldDrop("done"))
    #expect(!CatalogListing.shouldDrop("upcoming"))
    #expect(!CatalogListing.shouldDrop(nil))
    #expect(!CatalogListing.shouldFetchDetails("CANCELLED"))
    #expect(CatalogListing.shouldFetchDetails("CONTRACT"))
    #expect(
        DraftAssembler.draft(
            from: ProviderBookingFacts(
                provider: .getYourGuide,
                bookingType: .activity,
                start: .instant(Date(timeIntervalSince1970: 10)),
                end: .instant(Date(timeIntervalSince1970: 20)),
                statusRaw: "done"
            )
        ) == nil
    )
}

@Test func draftAssembler_hotelStayOffsetFallsBackToDeadlineOffset() throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let end = Date(timeIntervalSince1970: 1_700_086_400)
    let draft = try #require(
        DraftAssembler.draft(
            from: ProviderBookingFacts(
                provider: .check24,
                bookingType: .hotel,
                start: .hotelDay(start, offsetSeconds: nil),
                end: .hotelDay(end, offsetSeconds: nil),
                deadlines: [
                    CancellationDeadline(
                        deadlineAt: start,
                        isFreeCancellation: true,
                        hotelOffsetSeconds: 7200
                    )
                ]
            )
        )
    )
    #expect(draft.hotelOffsetSeconds == 7200)

    let flight = try #require(
        DraftAssembler.draft(
            from: ProviderBookingFacts(
                provider: .check24,
                bookingType: .flight,
                start: .instant(start),
                end: .instant(end),
                deadlines: [
                    CancellationDeadline(
                        deadlineAt: start,
                        isFreeCancellation: true,
                        hotelOffsetSeconds: 7200
                    )
                ]
            )
        )
    )
    #expect(flight.hotelOffsetSeconds == nil)
}

@Test func draftEnrichmentNeeds_matchesTravelokaMatrix() {
    let complete = ProviderBookingDraft(
        provider: .traveloka,
        bookingType: .hotel,
        title: "Example Hotel",
        startAt: Date(),
        endAt: Date(),
        locationToAddress: "Jl. Example No. 1, Cilandak, South Jakarta",
        status: .confirmed,
        deadlines: [
            CancellationDeadline(deadlineAt: Date(), policyText: "Free", isFreeCancellation: true),
            CancellationDeadline(
                deadlineAt: Date(),
                policyText: "Fee",
                isFreeCancellation: false,
                cancellationFeeAmount: 4.37
            ),
        ],
        rateDetails: BookingRateDetails(roomCategory: "Standard Double"),
        hotelCheckInMinutes: 14 * 60,
        hotelCheckOutMinutes: 12 * 60
    )
    #expect(DraftEnrichmentNeeds.shouldEnrich(complete, requiresDeadlines: true) == false)

    let missingCheckIn = ProviderBookingDraft(
        provider: .traveloka,
        bookingType: .hotel,
        startAt: Date(),
        endAt: Date(),
        status: .confirmed,
        deadlines: complete.deadlines,
        hotelCheckOutMinutes: 12 * 60
    )
    #expect(DraftEnrichmentNeeds.shouldEnrich(missingCheckIn, requiresDeadlines: true) == true)
}

@Test func draftEnrichmentNeeds_completeHotel_skipsForAllProviders() {
    for provider in [ProviderID.booking, .airbnb, .opodo, .traveloka, .check24] {
        let draft = catalogHotelDraft(provider: provider, externalUrl: "https://example.com/booking")
        #expect(DraftEnrichmentNeeds.shouldEnrich(draft, requiresDeadlines: false) == false)
    }
}

@Test func draftEnrichmentNeeds_completeActivity_skips() {
    let draft = ProviderBookingDraft(
        provider: .getYourGuide,
        bookingType: .activity,
        title: "City Tour",
        externalUrl: "https://www.getyourguide.com/booking",
        startAt: Date(),
        endAt: Date(),
        locationToAddress: "Berlin",
        operatorName: "Guide Co",
        isAllDay: false,
        status: .confirmed,
        passengers: [
            BookingPassenger(passengerNumber: 1, travellerType: .adult, givenName: "Ada"),
        ]
    )
    #expect(DraftEnrichmentNeeds.shouldEnrich(draft, requiresDeadlines: false) == false)
}

@Test func draftEnrichmentNeeds_hotelWithoutDeadlinesAlwaysEnriches() {
    let draft = ProviderBookingDraft(
        provider: .opodo,
        bookingType: .hotel,
        title: "Example Hotel",
        confirmationCode: "ABC123",
        externalUrl: "https://www.opodo.de/booking",
        startAt: Date(),
        endAt: Date(),
        locationToAddress: "Street 1, City",
        status: .confirmed,
        rateDetails: BookingRateDetails(roomCategory: "Standard Double"),
        hotelCheckInMinutes: 15 * 60,
        hotelCheckOutMinutes: 11 * 60
    )
    #expect(DraftEnrichmentNeeds.shouldEnrich(draft, requiresDeadlines: false) == true)
}

@Test func draftEnrichmentNeeds_unknownStatus_enriches() {
    var draft = catalogHotelDraft(provider: .booking, externalUrl: "https://secure.booking.com/confirmation")
    draft.status = .unknown
    #expect(DraftEnrichmentNeeds.shouldEnrich(draft, requiresDeadlines: false) == true)
}

@Test func draftEnrichmentNeeds_ferryFieldGaps() {
    let catalogShaped = ProviderBookingDraft(
        provider: .check24,
        bookingType: .ferry,
        title: "Kiel — Göteborg",
        externalUrl: "https://fahrplan.check24.de/ferry",
        startAt: Date(),
        endAt: Date(),
        locationTo: "Göteborg",
        status: .confirmed
    )
    #expect(DraftEnrichmentNeeds.shouldEnrich(catalogShaped, requiresDeadlines: false) == false)

    let missingDestination = ProviderBookingDraft(
        provider: .check24,
        bookingType: .ferry,
        startAt: Date(),
        endAt: Date(),
        status: .confirmed
    )
    #expect(DraftEnrichmentNeeds.shouldEnrich(missingDestination, requiresDeadlines: false) == true)

    let bothPortsWithoutOperator = ProviderBookingDraft(
        provider: .check24,
        bookingType: .ferry,
        title: "Kiel — Göteborg",
        externalUrl: "https://example.com/ferry",
        startAt: Date(),
        endAt: Date(),
        locationFrom: "Kiel",
        locationTo: "Göteborg",
        status: .confirmed
    )
    #expect(DraftEnrichmentNeeds.shouldEnrich(bothPortsWithoutOperator, requiresDeadlines: false) == true)

    var completeRoute = bothPortsWithoutOperator
    completeRoute.operatorName = "Stena Line"
    #expect(DraftEnrichmentNeeds.shouldEnrich(completeRoute, requiresDeadlines: false) == false)
}

@Test func draftEnrichmentNeeds_carRentalFieldGaps() {
    let complete = ProviderBookingDraft(
        provider: .check24,
        bookingType: .carRental,
        title: "Toyota Aygo",
        startAt: Date(),
        endAt: Date(),
        locationFrom: "Madeira Flughafen",
        locationTo: "Madeira Flughafen",
        locationFromAddress: "Madeira Airport, 9100-105 Madeira",
        locationToAddress: "Madeira Airport, 9100-105 Madeira",
        operatorName: "Car Alliance",
        status: .confirmed
    )
    #expect(DraftEnrichmentNeeds.shouldEnrich(complete, requiresDeadlines: false) == false)

    let missingPickup = ProviderBookingDraft(
        provider: .check24,
        bookingType: .carRental,
        title: "Toyota Aygo",
        startAt: Date(),
        endAt: Date(),
        locationTo: "Madeira Flughafen",
        locationFromAddress: "Madeira Airport",
        locationToAddress: "Madeira Airport",
        operatorName: "Car Alliance",
        status: .confirmed
    )
    #expect(DraftEnrichmentNeeds.shouldEnrich(missingPickup, requiresDeadlines: false) == true)

    let missingOperator = ProviderBookingDraft(
        provider: .check24,
        bookingType: .carRental,
        title: "Toyota Aygo",
        startAt: Date(),
        endAt: Date(),
        locationFrom: "Madeira Flughafen",
        locationTo: "Madeira Flughafen",
        locationFromAddress: "Madeira Airport",
        locationToAddress: "Madeira Airport",
        status: .confirmed
    )
    #expect(DraftEnrichmentNeeds.shouldEnrich(missingOperator, requiresDeadlines: false) == true)

    let missingDropoffAddress = ProviderBookingDraft(
        provider: .check24,
        bookingType: .carRental,
        title: "Toyota Aygo",
        startAt: Date(),
        endAt: Date(),
        locationFrom: "Madeira Flughafen",
        locationTo: "Madeira Flughafen",
        locationFromAddress: "Madeira Airport",
        operatorName: "Car Alliance",
        status: .confirmed
    )
    #expect(DraftEnrichmentNeeds.shouldEnrich(missingDropoffAddress, requiresDeadlines: false) == true)
}

@Test func bookingRateDetailsMerging_ignoresEmptyFingerprint() throws {
    let existing = BookingRateDetails(rawDetailsFingerprint: "real-fp", totalPriceAmount: 10)
    let incoming = BookingRateDetails(rawDetailsFingerprint: "", totalPriceAmount: 20)
    let merged = try #require(BookingRateDetails.merging(existing: existing, incoming: incoming))
    #expect(merged.rawDetailsFingerprint == "real-fp")
    #expect(merged.totalPriceAmount == 20)
}

@Test func bookingRateDetailsMerging_unknownBoardDoesNotClearBreakfast() throws {
    let existing = BookingRateDetails(
        boardType: .breakfastIncluded,
        includedBreakfast: true,
        roomCount: 1
    )
    let incoming = BookingRateDetails(
        boardType: .unknown,
        includedBreakfast: nil,
        guestCount: 2
    )
    let merged = try #require(BookingRateDetails.merging(existing: existing, incoming: incoming))
    #expect(merged.boardType == .breakfastIncluded)
    #expect(merged.includedBreakfast == true)
    #expect(merged.guestCount == 2)
    #expect(merged.roomCount == 1)
}

private func catalogHotelDraft(provider: ProviderID, externalUrl: String?) -> ProviderBookingDraft {
    ProviderBookingDraft(
        provider: provider,
        bookingType: .hotel,
        title: "Example Hotel",
        confirmationCode: "ABC123",
        externalUrl: externalUrl,
        startAt: Date(),
        endAt: Date(),
        locationToAddress: "Street 1, City",
        status: .confirmed,
        deadlines: [
            CancellationDeadline(deadlineAt: Date(), policyText: "Free", isFreeCancellation: true),
        ],
        rateDetails: BookingRateDetails(roomCategory: "Standard Double"),
        hotelCheckInMinutes: 15 * 60,
        hotelCheckOutMinutes: 11 * 60
    )
}
