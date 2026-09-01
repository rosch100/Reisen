import Foundation
import Testing
import ReisenDomain

private let cal = HotelStayDate.calendar

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
    #expect(BookingDayOverlap.countsByID([a, b]).isEmpty)
}

@Test func bookingDayOverlap_overlappingHotelRanges_countsBoth() {
    let a = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "A")
    let b = span(start: day(2026, 8, 2), end: day(2026, 8, 4), place: "B")
    let counts = BookingDayOverlap.countsByID([a, b])
    #expect(counts[a.id] == 1)
    #expect(counts[b.id] == 1)
}

@Test func bookingDayOverlap_samePlaceSameTrip_multiRoomSuppressed() {
    let trip = UUID()
    let a = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "Hotel", tripID: trip)
    let b = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "Hotel", tripID: trip)
    #expect(BookingDayOverlap.isSamePlaceAndDates(a, b))
    #expect(BookingDayOverlap.shouldSuppressAsMultiRoom(a, b))
    #expect(BookingDayOverlap.countsByID([a, b]).isEmpty)
}

@Test func bookingDayOverlap_samePlaceDifferentTrips_counts() {
    let a = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "Hotel", tripID: UUID())
    let b = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "Hotel", tripID: UUID())
    let counts = BookingDayOverlap.countsByID([a, b])
    #expect(counts[a.id] == 1)
    #expect(counts[b.id] == 1)
}

@Test func bookingDayOverlap_samePlaceOpenVsTrip_counts() {
    let a = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "Hotel", tripID: nil)
    let b = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "Hotel", tripID: UUID())
    #expect(BookingDayOverlap.countsByID([a, b])[a.id] == 1)
}

@Test func bookingDayOverlap_sameDayFlights_overlap() {
    let d = day(2026, 8, 1)
    let a = span(start: d, end: d, place: "FRA", type: .flight)
    let b = span(start: d, end: d, place: "MUC", type: .flight)
    let counts = BookingDayOverlap.countsByID([a, b])
    #expect(counts[a.id] == 1)
    #expect(counts[b.id] == 1)
}

@Test func bookingDayOverlap_flightOnHotelCheckoutDay_noOverlap() {
    let hotel = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "H", type: .hotel)
    let flight = span(start: day(2026, 8, 3), end: day(2026, 8, 3), place: "X", type: .flight)
    #expect(BookingDayOverlap.countsByID([hotel, flight]).isEmpty)
}

@Test func bookingDayOverlap_flightVsHotelOccupiedNight_counts() {
    let hotel = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "H", type: .hotel)
    let flight = span(start: day(2026, 8, 2), end: day(2026, 8, 2), place: "X", type: .flight)
    #expect(BookingDayOverlap.countsByID([hotel, flight])[hotel.id] == 1)
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
    #expect(BookingDayOverlap.countsByID([flight, hotelNight2])[flight.id] == 1)
}

@Test func bookingDayOverlap_carRentalInclusiveEnd_overlapsHotelOnReturnDay() {
    let car = span(start: day(2026, 8, 1), end: day(2026, 8, 3), place: "C", type: .carRental)
    let hotel = span(start: day(2026, 8, 3), end: day(2026, 8, 4), place: "H", type: .hotel)
    #expect(BookingDayOverlap.countsByID([car, hotel])[car.id] == 1)
}

@Test func bookingDayOverlap_invertedDates_emptyOccupancy_noOverlap() {
    let bad = span(start: day(2026, 8, 3), end: day(2026, 8, 1), place: "X", type: .flight)
    let other = span(start: day(2026, 8, 1), end: day(2026, 8, 2), place: "Y", type: .hotel)
    #expect(BookingDayOverlap.countsByID([bad, other]).isEmpty)
}

@Test func bookingDayOverlap_activitySameDay_counts() {
    let d = day(2026, 8, 5)
    let a = span(start: d, end: d, place: "TourA", type: .activity)
    let b = span(start: d, end: d, place: "TourB", type: .activity)
    #expect(BookingDayOverlap.countsByID([a, b])[a.id] == 1)
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

@Test func bookingDayOverlap_defaultCalendar_isHotelStayDate() {
    // Same absolute instants: device TZ must not change HotelStayDate-anchored days.
    let d1 = day(2026, 8, 1)
    let d2 = day(2026, 8, 2)
    let a = span(start: d1, end: d2, place: "A", type: .hotel)
    let b = span(start: d2, end: day(2026, 8, 3), place: "B", type: .hotel)
    #expect(BookingDayOverlap.countsByID([a, b]).isEmpty)
}
