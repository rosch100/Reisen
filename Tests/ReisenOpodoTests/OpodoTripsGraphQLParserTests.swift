import Testing
import Foundation
import ReisenOpodo
import ReisenDomain

@Test("OpodoTripsGraphQLParser parst Flug und aktives Hotel; RETAINED-Storno nicht im Katalog")
func opodoGraphQLParsesFlightAndHotel() throws {
    // HAR www.opodo.de 2026-07-20: getTrips UPCOMING — Flug, storniertes Hotel (RETAINED), aktives Hotel.
    let json = try fixtureJSON("getTrips_upcoming.json")
    let bookings = try OpodoTripsGraphQLParser().parseTrips(from: json)

    #expect(bookings.count == 2)

    let byType = Dictionary(grouping: bookings, by: \.bookingType)
    #expect(byType[.flight]?.count == 1)
    #expect(byType[.hotel]?.count == 1)
    #expect(bookings.contains { $0.title?.contains("Plataran") == true } == false)

    let flight = try #require(byType[.flight]?.first)
    #expect(flight.externalUrl?.contains("#tripdetails/td=") == true)
    #expect(flight.locationFrom == "Singapur (SIN)")
    #expect(flight.locationTo == "Jakarta (CGK)")
    #expect(flight.locationFromAddress == "Singapore Changi Airport")
    #expect(flight.locationToAddress == "Soekarno-Hatta International Airport")
    #expect(flight.confirmationCode == "1D9505")
    #expect(flight.status == .confirmed)
    #expect(flight.rateDetails?.airline == "TransNusa")
    #expect(flight.rateDetails?.passengerCount == 3)
    #expect(flight.rateDetails?.totalPriceAmount == 333.79)

    let active = try #require(byType[.hotel]?.first)
    #expect(active.title?.contains("Merlynn") == true)
    #expect(active.locationTo == "Jakarta")
    #expect(active.locationToAddress == "Jl. KH. Hasyim Azhari 29 - 31, 10130 Jakarta, ID")
    #expect(active.status == .confirmed)
    #expect(active.hotelCheckInMinutes == 14 * 60)
    #expect(active.hotelCheckOutMinutes == 12 * 60)
    #expect(active.rateDetails?.totalPriceAmount == 63.0)
    #expect(active.rateDetails?.totalPriceCurrency == "EUR")
    #expect(active.rateDetails?.boardType == .breakfastIncluded)
    #expect(active.rateDetails?.roomCategory == "Family Suite")
    #expect(active.rateDetails?.guestCount == 3)
}

@Test("OpodoTripsGraphQLParser liefert leere Liste ohne Trips")
func opodoGraphQLReturnsEmptyWhenNoTrips() throws {
    let json = #"{"data":{"getTrips":{"trips":[]}}}"#
    let bookings = try OpodoTripsGraphQLParser().parseTrips(from: json)
    #expect(bookings.isEmpty)
}

@Test("OpodoGetTripsQuery requestBody enthält Filter, Pagination und Katalogfelder")
func opodoGetTripsQueryRequestBody() throws {
    let data = try OpodoGetTripsQuery.requestBody(
        filter: "UPCOMING",
        maxNumBookingsByPage: 20,
        offsetPage: 0
    )
    let text = String(data: data, encoding: .utf8) ?? ""
    #expect(text.contains("getTrips"))
    #expect(text.contains("UPCOMING"))
    #expect(text.contains("tdToken"))
    #expect(text.contains("address"))
    #expect(text.contains("postalCode"))
    #expect(text.contains("bookingRooms"))
    #expect(text.contains("roomDescription"))
    #expect(text.contains("carrier"))
    #expect(text.contains("travellers"))
}

private func fixtureJSON(_ name: String) throws -> String {
    try TestFixtures.text(name)
}
