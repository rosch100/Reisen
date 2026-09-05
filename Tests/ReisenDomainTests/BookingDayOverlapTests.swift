import Foundation
import Testing
import ReisenDomain

private let cal = HotelStayDate.calendar
/// Vor den Aug-2026-Fixtures, damit Elapsed-Filter die Legacy-Tests nicht leert.
private let fixtureNow = cal.date(from: DateComponents(year: 2026, month: 7, day: 1))!

private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d))!
}

private func span(
    id: UUID = UUID(),
    start: Date,
    end: Date,
    place: String,
    tripID: UUID? = nil,
    type: BookingType = .hotel
) -> BookingDaySpan {
    BookingDaySpan(
        id: id,
        startAt: start,
        endAt: end,
        placeKey: place,
        tripID: tripID,
        bookingType: type
    )
}

@Test func bookingDayOverlap_adjacentHotelCheckoutCheckin_doesNotOverlap() {
    let day1 = day(2026, 8, 1)
    let day2 = day(2026, 8, 2)
    let day3 = day(2026, 8, 3)
    let a = span(start: day1, end: day2, place: "SIN", type: .hotel)
    let b = span(start: day2, end: day3, place: "BKK", type: .hotel)
    #expect(BookingDayOverlap.dayRangesOverlap(a, b) == false)
    #expect(BookingDayOverlap.countsByID([a, b], now: fixtureNow).isEmpty)
}

@Test func bookingDayOverlap_overlappingHotelRanges_countsBoth() {
    let a = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "A")
    let b = span(start: day(2026, 8, 2), end: day(2026, 8, 4), place: "B")
    let counts = BookingDayOverlap.countsByID([a, b], now: fixtureNow)
    #expect(counts[a.id] == 1)
    #expect(counts[b.id] == 1)
}

@Test func bookingDayOverlap_samePlaceSameTrip_multiRoomSuppressed() {
    let trip = UUID()
    let a = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "Hotel", tripID: trip)
    let b = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "Hotel", tripID: trip)
    #expect(BookingDayOverlap.isSamePlaceAndDates(a, b))
    #expect(BookingDayOverlap.shouldSuppressAsMultiRoom(a, b))
    #expect(BookingDayOverlap.countsByID([a, b], now: fixtureNow).isEmpty)
}

@Test func bookingDayOverlap_samePlaceDifferentTrips_counts() {
    let a = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "Hotel", tripID: UUID())
    let b = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "Hotel", tripID: UUID())
    let counts = BookingDayOverlap.countsByID([a, b], now: fixtureNow)
    #expect(counts[a.id] == 1)
    #expect(counts[b.id] == 1)
}

@Test func bookingDayOverlap_samePlaceOpenVsTrip_counts() {
    let a = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "Hotel", tripID: nil)
    let b = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "Hotel", tripID: UUID())
    #expect(BookingDayOverlap.countsByID([a, b], now: fixtureNow)[a.id] == 1)
}

@Test func bookingDayOverlap_sameDayFlights_overlap() {
    let d = day(2026, 8, 1)
    let a = span(start: d, end: d, place: "FRA", type: .flight)
    let b = span(start: d, end: d, place: "MUC", type: .flight)
    let counts = BookingDayOverlap.countsByID([a, b], now: fixtureNow)
    #expect(counts[a.id] == 1)
    #expect(counts[b.id] == 1)
}

@Test func bookingDayOverlap_flightOnHotelCheckoutDay_noOverlap() {
    let hotel = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "H", type: .hotel)
    let flight = span(start: day(2026, 8, 3), end: day(2026, 8, 3), place: "X", type: .flight)
    #expect(BookingDayOverlap.countsByID([hotel, flight], now: fixtureNow).isEmpty)
}

@Test func bookingDayOverlap_flightVsHotelOccupiedNight_counts() {
    let hotel = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "H", type: .hotel)
    let flight = span(start: day(2026, 8, 2), end: day(2026, 8, 2), place: "X", type: .flight)
    #expect(BookingDayOverlap.countsByID([hotel, flight], now: fixtureNow)[hotel.id] == 1)
}

@Test func bookingDayOverlap_overnightFlight_occupiesBothDays() {
    let flight = span(
        start: day(2026, 8, 1),
        end: day(2026, 8, 2),
        place: "X",
        type: .flight
    )
    let hotelNight2 = span(
        start: day(2026, 8, 2),
        end: day(2026, 8, 3),
        place: "H",
        type: .hotel
    )
    #expect(BookingDayOverlap.countsByID([flight, hotelNight2], now: fixtureNow)[flight.id] == 1)
}

@Test func bookingDayOverlap_carRentalInclusiveEnd_overlapsHotelOnReturnDay() {
    let car = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "C", type: .carRental)
    let hotel = span(start: day(2026, 8, 3), end: day(2026, 8, 4), place: "H", type: .hotel)
    #expect(BookingDayOverlap.countsByID([car, hotel], now: fixtureNow)[car.id] == 1)
}

@Test func bookingDayOverlap_invertedDates_emptyOccupancy_noOverlap() {
    let bad = span(start: day(2026, 8, 3), end: day(2026, 8, 1), place: "X", type: .flight)
    let other = span(start: day(2026, 8, 1), end: day(2026, 8, 2), place: "Y", type: .hotel)
    #expect(BookingDayOverlap.countsByID([bad, other], now: fixtureNow).isEmpty)
}

@Test func bookingDayOverlap_activitySameDay_counts() {
    let d = day(2026, 8, 5)
    let a = span(start: d, end: d, place: "TourA", type: .activity)
    let b = span(start: d, end: d, place: "TourB", type: .activity)
    #expect(BookingDayOverlap.countsByID([a, b], now: fixtureNow)[a.id] == 1)
}

@Test func bookingDayOverlap_isEligible_excludesCancelledOnly() {
    #expect(BookingDayOverlap.isEligible(status: .confirmed))
    #expect(BookingDayOverlap.isEligible(status: .unknown))
    #expect(!BookingDayOverlap.isEligible(status: .cancelled))
}

@Test func bookingType_usesStayLikeOverlapEnd_onlyHotel() {
    for type in BookingType.allCases {
        #expect(type.usesStayLikeOverlapEnd == (type == .hotel))
    }
}

@Test func bookingType_usesHotelStayDateAnchors_onlyHotel() {
    for type in BookingType.allCases {
        #expect(type.usesHotelStayDateAnchors == (type == .hotel))
        #expect(
            type.listInclusionCalendar.timeZone.secondsFromGMT()
                == (type == .hotel
                    ? HotelStayDate.timeZone.secondsFromGMT()
                    : Calendar.current.timeZone.secondsFromGMT())
        )
    }
}

@Test func bookingDayOverlap_defaultCalendar_isHotelStayDate() {
    // Same absolute instants: device TZ must not change HotelStayDate-anchored days.
    let d1 = day(2026, 8, 1)
    let d2 = day(2026, 8, 2)
    let a = span(start: d1, end: d2, place: "A", type: .hotel)
    let b = span(start: d2, end: day(2026, 8, 3), place: "B", type: .hotel)
    #expect(BookingDayOverlap.countsByID([a, b], now: fixtureNow).isEmpty)
}

@Test func bookingDayOverlap_samePlaceNormalizedIata_multiRoomSuppressed() {
    let trip = UUID()
    let d1 = day(2026, 8, 1)
    let d3 = day(2026, 8, 3)
    let aBooking = Booking(
        provider: .manual,
        bookingType: .hotel,
        startAt: d1,
        endAt: d3,
        locationTo: "Marina Bay Sands (SIN)",
        tripID: trip
    )
    let bBooking = Booking(
        provider: .manual,
        bookingType: .hotel,
        startAt: d1,
        endAt: d3,
        locationTo: "SIN",
        tripID: trip
    )
    #expect(aBooking.daySpan.placeKey == "SIN")
    #expect(bBooking.daySpan.placeKey == "SIN")
    #expect(BookingDayOverlap.countsByID([aBooking.daySpan, bBooking.daySpan], now: fixtureNow).isEmpty)
}

@Test func bookingDayOverlap_hotelSameCalendarDay_emptyOccupancy() {
    let d = day(2026, 8, 1)
    let hotel = span(start: d, end: d, place: "H", type: .hotel)
    let flight = span(start: d, end: d, place: "X", type: .flight)
    #expect(BookingDayOverlap.dayRangesOverlap(hotel, flight) == false)
    #expect(BookingDayOverlap.countsByID([hotel, flight], now: fixtureNow).isEmpty)
}

@Test func bookingDayOverlap_elapsedBookings_excludedFromPool() {
    let now = day(2026, 9, 1)
    let a = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "A")
    let b = span(start: day(2026, 8, 2), end: day(2026, 8, 4), place: "B")
    #expect(BookingDayOverlap.partnerIDsByID([a, b], now: now).isEmpty)
    #expect(BookingDayOverlap.countsByID([a, b], now: now).isEmpty)
}

@Test func bookingDayOverlap_activeVsElapsedPartner_excluded() {
    let now = day(2026, 9, 1)
    let active = span(
        start: day(2026, 8, 28),
        end: day(2026, 9, 5),
        place: "Active"
    )
    let elapsed = span(
        start: day(2026, 8, 28),
        end: day(2026, 8, 30),
        place: "Past"
    )
    #expect(BookingDayOverlap.partnerIDsByID([active, elapsed], now: now).isEmpty)
}

@Test func bookingDayOverlap_partnerIDsByID_returnsOtherBookingIDs() {
    let now = day(2026, 7, 1)
    let aID = UUID()
    let bID = UUID()
    let a = span(id: aID, start: day(2026, 8, 1), end: day(2026, 8, 3), place: "A")
    let b = span(id: bID, start: day(2026, 8, 2), end: day(2026, 8, 4), place: "B")
    let partners = BookingDayOverlap.partnerIDsByID([a, b], now: now)
    #expect(partners[aID] == [bID])
    #expect(partners[bID] == [aID])
}
