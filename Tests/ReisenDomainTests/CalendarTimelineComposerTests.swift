import Testing
import Foundation
import ReisenDomain

@Test func composeTripStartEndCreatesAllDayDrafts() {
    let trip = Trip(
        title: "Berlin",
        startDate: Date(timeIntervalSince1970: 1_700_000_000),
        endDate: Date(timeIntervalSince1970: 1_700_086_400),
        bookingIDs: []
    )

    let composer = CalendarTimelineComposer()
    let drafts = composer.compose(
        trips: [trip],
        bookings: [],
        bookingTitles: [:],
        includeTripStartEnd: true,
        includeFlightTimes: false,
        includeHotelStays: false
    )

    #expect(drafts.count == 2)
    #expect(drafts.contains(where: { $0.role == .tripStart && $0.isAllDay == true }))
    #expect(drafts.contains(where: { $0.role == .tripEnd && $0.isAllDay == true }))
}

@Test func composeHotelStayNotesIncludeCheckInOutWhenMinutesKnown() {
    let bookingID = UUID()
    let hotelBooking = Booking(
        id: bookingID,
        provider: .opodo,
        bookingType: .hotel,
        title: "Hotel Example",
        confirmationCode: "ABC123",
        externalUrl: "https://example.com/hotel",
        startAt: Date(timeIntervalSince1970: 1_700_000_000),
        endAt: Date(timeIntervalSince1970: 1_700_086_400),
        hotelOffsetSeconds: 2 * 3600,
        hotelCheckInMinutes: 14 * 60,
        hotelCheckOutMinutes: 12 * 60,
        locationFrom: "TestTown",
        locationTo: "TestTown",
        locationFromAddress: nil,
        locationToAddress: nil
    )

    let trip = Trip(
        title: "Berlin",
        startDate: Date(timeIntervalSince1970: 1_700_000_000),
        endDate: Date(timeIntervalSince1970: 1_700_086_400),
        bookingIDs: [bookingID]
    )

    let composer = CalendarTimelineComposer()
    let drafts = composer.compose(
        trips: [trip],
        bookings: [hotelBooking],
        bookingTitles: [bookingID: "Hotel Example"],
        includeTripStartEnd: false,
        includeFlightTimes: false,
        includeHotelStays: true
    )

    #expect(drafts.count == 1)
    guard let draft = drafts.first else { return }
    #expect(draft.role == CalendarEventRole.hotelStay)

    let notes = draft.notes ?? ""
    #expect(notes.contains("Hotel: Hotel Example"))
    #expect(notes.contains("Bestätigung: ABC123"))
    #expect(notes.contains("Check-in: 14:00"))
    #expect(notes.contains("Check-out: 12:00"))
    #expect(draft.url?.absoluteString == "https://example.com/hotel")
    #expect(draft.locationAddress == nil) // since only locationTo/locationToAddress are nil
    #expect(draft.locationQuery == "TestTown")
}

@Test func composeHotelStayNotesOmitCheckInOutWhenMinutesMissing() {
    let bookingID = UUID()
    let hotelBooking = Booking(
        id: bookingID,
        provider: .opodo,
        bookingType: .hotel,
        title: "Hotel Example",
        confirmationCode: nil,
        startAt: Date(timeIntervalSince1970: 1_700_000_000),
        endAt: Date(timeIntervalSince1970: 1_700_086_400),
        hotelOffsetSeconds: 2 * 3600,
        hotelCheckInMinutes: nil,
        hotelCheckOutMinutes: nil,
        locationFrom: "TestTown",
        locationTo: "TestTown"
    )

    let trip = Trip(
        title: "Berlin",
        startDate: Date(timeIntervalSince1970: 1_700_000_000),
        endDate: Date(timeIntervalSince1970: 1_700_086_400),
        bookingIDs: [bookingID]
    )

    let composer = CalendarTimelineComposer()
    let drafts = composer.compose(
        trips: [trip],
        bookings: [hotelBooking],
        bookingTitles: [bookingID: "Hotel Example"],
        includeTripStartEnd: false,
        includeFlightTimes: false,
        includeHotelStays: true
    )

    #expect(drafts.count == 1)
    let notes = drafts.first?.notes ?? ""
    #expect(notes.contains("Hotel: Hotel Example"))
    #expect(!notes.contains("Check-in:"))
    #expect(!notes.contains("Check-out:"))
}

@Test func composeFlightDepartureUsesResolvedAddressWhenAvailable() {
    let bookingID = UUID()
    let flightBooking = Booking(
        id: bookingID,
        provider: .opodo,
        bookingType: .flight,
        title: "LH 123",
        externalUrl: "https://example.com/booking",
        startAt: Date(timeIntervalSince1970: 1_700_000_000),
        endAt: Date(timeIntervalSince1970: 1_700_003_600),
        flightDepartureOffsetSeconds: 2 * 3600,
        flightArrivalOffsetSeconds: 2 * 3600,
        locationFrom: "MUC",
        locationTo: "BER",
        locationFromAddress: "Munich Airport, Germany",
        locationToAddress: nil,
        rateDetails: BookingRateDetails(
            boardType: .unknown,
            airline: "Lufthansa"
        )
    )

    let trip = Trip(
        title: "Berlin",
        startDate: Date(timeIntervalSince1970: 1_700_000_000),
        endDate: Date(timeIntervalSince1970: 1_700_003_600),
        bookingIDs: [bookingID]
    )

    let composer = CalendarTimelineComposer()
    let drafts = composer.compose(
        trips: [trip],
        bookings: [flightBooking],
        bookingTitles: [bookingID: "LH 123"],
        includeTripStartEnd: false,
        includeFlightTimes: true,
        includeHotelStays: false
    )

    #expect(drafts.count == 1)
    let dep = drafts.first(where: { $0.role == CalendarEventRole.flightDeparture })
    #expect(dep?.locationAddress == "Munich Airport, Germany")
    #expect(dep?.locationQuery == nil) // resolved address wins
    #expect(dep?.url?.absoluteString == "https://example.com/booking")
    #expect(dep?.title == "LH 123 – Lufthansa")
    let notes = dep?.notes ?? ""
    #expect(notes.contains("Fluggesellschaft: Lufthansa"))
    #expect(!drafts.contains(where: { $0.role == CalendarEventRole.flightArrival }))
}

