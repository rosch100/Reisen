import Testing
import Foundation
import ReisenDomain
@testable import ReisenAirbnb

@Test("AirbnbScheduledEventsParser parst Stay Preis, Check-in/out Minuten und Stornofrist")
func airbnbScheduledEventsParsesPriceDeadlinesAndTimes() throws {
    let json = try fixtureJSON("scheduled_events_stay_sample.json")
    let result = try AirbnbScheduledEventsParser.parse(responseText: json)

    #expect(result.rateDetails?.totalPriceAmount == 52.56)
    #expect(result.rateDetails?.totalPriceCurrency == "EUR")

    #expect(result.hotelCheckInMinutes == 23 * 60)
    #expect(result.hotelCheckOutMinutes == 11 * 60)

    #expect(result.deadlines.count == 1)
    let deadline = try #require(result.deadlines.first)

    let expected = iso8601("2026-02-03T13:37:33.854Z")
    #expect(abs(deadline.deadlineAt.timeIntervalSince(expected)) < 0.01)
    #expect(deadline.isFreeCancellation == false)
    #expect(deadline.policyText?.contains("nicht erstattungsfähig") == true)
}

@Test("AirbnbTripDetailsParser parst Zeitzone, Adresse, Gäste und Raumanzahl")
func airbnbTripDetailsParsesAddressGuestsAndTimezone() throws {
    let json = try fixtureJSON("trip_details_sample.json")
    let confirmationCode = "HMSN84QMWF"

    let details = try AirbnbTripDetailsParser.parse(
        responseText: json,
        bookingType: .hotel,
        confirmationCode: confirmationCode
    )

    #expect(details.listingTimeZone == "Europe/Vienna")
    #expect(details.tripStartAt == iso8601("2026-02-03T22:00:00.000Z"))
    #expect(details.tripEndAt == iso8601("2026-02-04T10:00:00.000Z"))
    #expect(details.oneLineAddress == "Mauern 83, Mauern, Tirol 6150, Österreich")
    #expect(details.guestAdults == 1)
    #expect(details.roomCount == 1)
    #expect(details.reservationStatus == "ACCEPT")
    #expect(details.confirmationCode == confirmationCode)
}

@Test("AirbnbTripsGraphQLParser mappt EXPERIENCE_RESERVATION auf BookingType.activity")
func airbnbTripListMapsExperienceToActivity() throws {
    let json = try researchFixtureJSON("airbnb_TripListQuery_experience_redacted.json")
    let catalog = try AirbnbTripsGraphQLParser.parseTripList(from: json)

    #expect(catalog.bookings.count == 1)
    let draft = try #require(catalog.bookings.first)
    #expect(draft.bookingType == .activity)
    #expect(draft.provider == .airbnb)
    #expect(draft.confirmationCode == "<REDACTED>")
    #expect(draft.status == .confirmed)
    #expect(draft.title == "Gedong Tengen")
    #expect(draft.passengers.count == 3)
    #expect(draft.passengers.allSatisfy { $0.travellerType == .adult })
    #expect(draft.startAt == iso8601("2026-08-10T11:00:00.000Z"))
    #expect(draft.endAt == iso8601("2026-08-10T14:00:00.000Z"))
    #expect(draft.externalUrl?.contains("EXPERIENCE_RESERVATION") == true)
}

@Test("AirbnbActivityReservationDetailsParser parst Marquee, Treffpunkt, Gäste, Preis und Storno")
func airbnbActivityReservationDetailsParsesEnrichmentFields() throws {
    let json = try researchFixtureJSON("airbnb_activity_reservation_details_redacted.json")
    let reference = iso8601("2026-08-10T11:00:00.000Z")
    let result = try AirbnbActivityReservationDetailsParser.parse(
        responseText: json,
        referenceDate: reference
    )

    #expect(result.title == "Yogyakarta Night Tour: Food & Cultural Experience")
    #expect(result.locationTo == "Slasar Malioboro, Jalan Pasar Kembang No.30B")
    #expect(result.locationToAddress?.contains("Gedong Tengen") == true)
    #expect(result.guestAdults == 3)
    #expect(result.confirmationCode == "TAJ8FMXK")
    #expect(result.experienceWebPath == "/experiences/687240")

    #expect(result.rateDetails?.totalPriceAmount == 41.61)
    #expect(result.rateDetails?.totalPriceCurrency == "EUR")

    #expect(result.deadlines.count == 1)
    let deadline = try #require(result.deadlines.first)
    #expect(deadline.isFreeCancellation == true)
    #expect(deadline.policyText?.contains("full refund") == true)

    let expectedDeadline = try #require(
        dateInTimeZone(
            year: 2026,
            month: 8,
            day: 9,
            hour: 18,
            minute: 0,
            timeZoneID: "Asia/Jakarta"
        )
    )
    #expect(abs(deadline.deadlineAt.timeIntervalSince(expectedDeadline)) < 0.01)
}

private func fixtureJSON(_ name: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
    return try String(contentsOf: url, encoding: .utf8)
}

private func researchFixtureJSON(_ name: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Tests/ReisenAirbnbTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // repo root
        .appendingPathComponent("docs/fixtures/provider-research")
        .appendingPathComponent(name)
    return try String(contentsOf: url, encoding: .utf8)
}

private func iso8601(_ value: String) -> Date {
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fmt.date(from: value)!
}

private func dateInTimeZone(
    year: Int,
    month: Int,
    day: Int,
    hour: Int,
    minute: Int,
    timeZoneID: String
) -> Date? {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(identifier: timeZoneID)
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = 0
    return components.date
}
