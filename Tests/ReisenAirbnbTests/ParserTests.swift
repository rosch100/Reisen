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

private func fixtureJSON(_ name: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
    return try String(contentsOf: url, encoding: .utf8)
}

private func iso8601(_ value: String) -> Date {
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fmt.date(from: value)!
}

