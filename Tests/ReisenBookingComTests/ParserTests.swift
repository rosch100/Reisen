import Testing
import Foundation
import ReisenBookingCom
import ReisenDomain

@Test("BookingComActivityListParser parst Buchungen aus HTML (hotel)")
func bookingComParsesHotels() throws {
    let html = """
    <html>
      <body>
        <a href="https://www.booking.com/hotel/de/hotelname.de.html" data-start="2026-08-01" data-end="2026-08-05">Hotel</a>
        <a href="https://www.booking.com/flight/de/flightname.html" data-start="2026-08-10" data-end="2026-08-11">Flight</a>
      </body>
    </html>
    """

    let bookings = try BookingComActivityListParser().parseBookings(from: html)
    #expect(bookings.count == 2)

    let typesByUrl = Dictionary(bookings.map { ($0.externalUrl, $0.bookingType) }, uniquingKeysWith: { $1 })
    #expect(typesByUrl["https://www.booking.com/hotel/de/hotelname.de.html"] == .hotel)
    #expect(typesByUrl["https://www.booking.com/flight/de/flightname.html"] == .flight)
}

@Test("BookingComActivityListParser wirft bei fehlenden Bookings")
func bookingComThrowsWhenNoBookingsFound() {
    let html = "<html><body><p>no bookings</p></body></html>"
    #expect(throws: BookingComActivityListParserError.noBookingsFound) {
        _ = try BookingComActivityListParser().parseBookings(from: html)
    }
}

@Test("BookingComCancellationDeadlineParser ohne Hotel-Offset liefert keine Fristen")
func bookingComCancellationParserRequiresHotelOffset() {
    let html = """
    <html><body>
      <ul class="e2e-cancellation-breakdown">
        <li>bis 10. August 2026 23:59: € 0</li>
      </ul>
    </body></html>
    """
    let deadlines = BookingComCancellationDeadlineParser().parseDeadlines(from: html)
    #expect(deadlines.isEmpty)
}

@Test("BookingComCancellationDeadlineParser Keyword: vor dem → Vortag 23:59 Hotel-TZ")
func bookingComCancellationParserExclusiveVorDem() throws {
    let html = """
    <html><body>
      <p>Sie können diese Buchung vor dem Di., 11. August 2026 kostenlos stornieren.</p>
    </body></html>
    """
    let offset = 2 * 3600
    let deadlines = BookingComCancellationDeadlineParser().parseDeadlines(
        from: html,
        hotelOffsetSeconds: offset
    )
    let free = try #require(deadlines.first { $0.isFreeCancellation })
    let tz = TimeZone(secondsFromGMT: offset)!
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tz
    let comps = cal.dateComponents([.day, .hour, .minute], from: free.deadlineAt)
    #expect(comps.day == 10)
    #expect(comps.hour == 23)
    #expect(comps.minute == 59)
}

@Test("BookingComCancellationDeadlineParser: Fee-Schedule-Markup ohne Zeilen → kein Keyword-Fallback")
func bookingComCancellationParserDoesNotKeywordFallbackWhenFeeMarkupPresent() {
    let html = """
    <html><body>
      <table class="e2e-conf-cancellation-cost"><tr><td>
        <ul class="e2e-cancellation-breakdown"><li>keine lesbaren Beträge</li></ul>
        <p>Sie können diese Buchung vor dem Di., 11. August 2026 kostenlos stornieren.</p>
        <p>gemäß der Zeitzone der Unterkunft</p>
      </td></tr></table>
    </body></html>
    """
    let deadlines = BookingComCancellationDeadlineParser().parseDeadlines(
        from: html,
        hotelOffsetSeconds: 2 * 3600
    )
    #expect(deadlines.isEmpty)
}

@Test("BookingComCancellationDeadlineParser parst HAR Confirmation Fee-Schedule (Langdatum + Hotel-TZ)")
func bookingComCancellationParserParsesHarConfirmationFeeSchedule() throws {
    let html = try fixtureJSON("hotel_confirmation_sample.html")
    let offset = 2 * 3600 // Europe/Berlin Sommerzeit (Unterkunft München)
    let deadlines = BookingComCancellationDeadlineParser().parseDeadlines(
        from: html,
        hotelOffsetSeconds: offset
    )
    #expect(deadlines.count == 2)
    let free = try #require(deadlines.first { $0.cancellationFeeAmount == 0 })
    let paid = try #require(deadlines.first { $0.cancellationFeeAmount == 121.64 })
    #expect(free.isFreeCancellation)
    #expect(!paid.isFreeCancellation)
    #expect(free.hotelOffsetSeconds == offset)
    #expect(paid.hotelOffsetSeconds == offset)
    #expect(free.policyText?.contains("10. August 2026 23:59") == true)
    #expect(paid.policyText?.contains("11. August 2026 00:00") == true)

    let tz = TimeZone(secondsFromGMT: offset)!
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tz
    let freeComps = cal.dateComponents([.day, .month, .year, .hour, .minute], from: free.deadlineAt)
    #expect(freeComps.year == 2026)
    #expect(freeComps.month == 8)
    #expect(freeComps.day == 10)
    #expect(freeComps.hour == 23)
    #expect(freeComps.minute == 59)
    let paidComps = cal.dateComponents([.day, .hour, .minute], from: paid.deadlineAt)
    #expect(paidComps.day == 11)
    #expect(paidComps.hour == 0)
    #expect(paidComps.minute == 0)
}

@Test("BookingComCancellationDeadlineParser parst numerisches dd.MM.yyyy Fee-Schedule")
func bookingComCancellationParserParsesNumericFeeSchedule() throws {
    let html = """
    <html><body>
      <p>Kostenlose Stornierung bis 10.08.2026 23:59 → &euro;&nbsp;0</p>
      <p>Ab 11.08.2026 00:00 Stornogebühr &euro;&nbsp;121,64</p>
    </body></html>
    """
    let offset = 2 * 3600
    let deadlines = BookingComCancellationDeadlineParser().parseDeadlines(
        from: html,
        hotelOffsetSeconds: offset
    )
    #expect(deadlines.contains { $0.cancellationFeeAmount == 0 })
    #expect(deadlines.contains { $0.cancellationFeeAmount == 121.64 })
}

@Test("Fixture-Katalog liefert alle persistierbaren Kernfelder für Flug und Hotel")
func bookingComFixtureFillsPersistableCoreFields() throws {
    let json = try fixtureJSON("single_timeline_kuta_muenchen.json")
    let bookings = try BookingComTripsGraphQLParser().parseTimeline(from: json)
    let byType = Dictionary(grouping: bookings, by: \.bookingType)

    let flight = try #require(byType[.flight]?.first)
    #expect(flight.provider == .booking)
    #expect(flight.externalUrl != nil)
    #expect(flight.confirmationCode != nil)
    #expect(flight.title != nil)
    #expect(flight.locationFrom?.contains("YIA") == true)
    #expect(flight.locationTo?.contains("DPS") == true)
    #expect(flight.rateDetails?.totalPriceAmount != nil)
    #expect(flight.rateDetails?.totalPriceCurrency == "EUR")
    #expect(flight.rateDetails?.airline == "IU")
    #expect(flight.rateDetails?.passengerCount == 3)
    #expect(flight.flightDepartureOffsetSeconds == 7 * 3600)
    #expect(flight.flightArrivalOffsetSeconds == 8 * 3600)
    #expect(flight.status == .confirmed)
    // Nicht stornierbar in HAR → keine Dummy-Frist
    #expect(flight.deadlines.isEmpty)

    let hotel = try #require(byType[.hotel]?.first)
    #expect(hotel.provider == .booking)
    #expect(hotel.externalUrl != nil)
    #expect(hotel.confirmationCode == "6806647309")
    #expect(hotel.title == "Hotel Am Nockherberg")
    #expect(hotel.locationTo == "München")
    #expect(hotel.locationToAddress == "Nockherstraße 38 A")
    #expect(hotel.hotelOffsetSeconds == 7200)
    #expect(hotel.hotelCheckInMinutes == 900)
    #expect(hotel.hotelCheckOutMinutes == 660)
    #expect(hotel.rateDetails?.totalPriceAmount == 135.15)
    #expect(hotel.rateDetails?.roomCount == 1)
    #expect(hotel.deadlines.count == 1)
    #expect(hotel.deadlines.first?.isFreeCancellation == true)
    #expect(hotel.deadlines.first?.hotelOffsetSeconds == 7200)
}

@Test("Confirmation-Fixture + Hotel-Offset liefert beide Fee-Stufen wie HAR")
func bookingComConfirmationFixtureFeeScheduleMatchesHAR() throws {
    let html = try fixtureJSON("hotel_confirmation_sample.html")
    let offset = 2 * 3600
    let deadlines = BookingComCancellationDeadlineParser().parseDeadlines(
        from: html,
        hotelOffsetSeconds: offset
    )
    #expect(deadlines.count == 2)
    #expect(deadlines.contains { $0.cancellationFeeAmount == 0 && $0.isFreeCancellation })
    #expect(deadlines.contains { $0.cancellationFeeAmount == 121.64 && !$0.isFreeCancellation })
    #expect(deadlines.allSatisfy { $0.hotelOffsetSeconds == offset })
}

private func fixtureJSON(_ name: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
    return try String(contentsOf: url, encoding: .utf8)
}

