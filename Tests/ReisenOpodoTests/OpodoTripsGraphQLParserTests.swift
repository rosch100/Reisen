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
    #expect(text.contains("transportTypes"))
    #expect(!text.contains("insuranceBookings"))
    #expect(!text.contains("GetVehicleRentalOffers"))
    #expect(!text.contains("VR_getTransferOffers"))
}

@Test("OpodoTripsGraphQLParser ignoriert Upsell ohne Flug/Hotel")
func opodoGraphQLSkipsInsuranceOnlyTrip() throws {
    let json = """
    {"data":{"getTrips":{"trips":[
      {"trip":{"id":"ins-1","tdToken":"FAKE_TOKEN_INSURANCE","itinerary":null,"accommodationBooking":null}}
    ]}}}
    """
    let page = try OpodoTripsGraphQLParser().parseTripPage(from: json)
    #expect(page.rawTripCount == 1)
    #expect(page.bookings.isEmpty)
}

@Test("OpodoTripsGraphQLParser ignoriert Nicht-Flug-Itinerary")
func opodoGraphQLSkipsNonPlaneItinerary() throws {
    let json = """
    {"data":{"getTrips":{"trips":[
      {"trip":{"id":"rail-1","tdToken":"FAKE_TOKEN_TRAIN","itinerary":{
        "transportTypes":["TRAIN"],
        "departureDate":1785843900000,
        "arrivalDate":1785846600000,
        "origin":{"cityName":"Berlin","iata":"BER"},
        "destination":{"cityName":"München","iata":"MUC"}
      },"accommodationBooking":null}}
    ]}}}
    """
    let bookings = try OpodoTripsGraphQLParser().parseTrips(from: json)
    #expect(bookings.isEmpty)
}

@Test("OpodoTripsGraphQLParser ignoriert Itinerary ohne transportTypes")
func opodoGraphQLSkipsItineraryWithoutTransportTypes() throws {
    let json = """
    {"data":{"getTrips":{"trips":[
      {"trip":{"id":"unk-1","tdToken":"FAKE_TOKEN_NO_TYPES","itinerary":{
        "departureDate":1785843900000,
        "arrivalDate":1785846600000,
        "origin":{"cityName":"Berlin","iata":"BER"},
        "destination":{"cityName":"München","iata":"MUC"}
      },"accommodationBooking":null}}
    ]}}}
    """
    let page = try OpodoTripsGraphQLParser().parseTripPage(from: json)
    #expect(page.rawTripCount == 1)
    #expect(page.bookings.isEmpty)
}

@Test("OpodoTripsGraphQLParser wirft bei USER_NOT_LOGGED_IN statt leerer Liste")
func opodoGraphQLThrowsWhenNotLoggedIn() {
    let json = #"{"errors":[{"message":"Internal error","extensions":{"errorCode":"USER_NOT_LOGGED_IN"}}]}"#
    #expect(throws: OpodoTripsGraphQLParserError.notLoggedIn) {
        try OpodoTripsGraphQLParser().parseTrips(from: json)
    }
}

@Test("OpodoTripsGraphQLParser wirft USER_NOT_LOGGED_IN auch wenn Trip-Rows da sind")
func opodoGraphQLThrowsNotLoggedInEvenWithTripRows() {
    let json = """
    {"data":{"getTrips":{"trips":[{"trip":{"id":"x","tdToken":"FAKE"}}]}},
     "errors":[{"message":"Internal error","extensions":{"errorCode":"USER_NOT_LOGGED_IN"}}]}
    """
    #expect(throws: OpodoTripsGraphQLParserError.notLoggedIn) {
        try OpodoTripsGraphQLParser().parseTrips(from: json)
    }
}

@Test("OpodoTripsGraphQLParser nutzt Trip-Rows trotz nicht-fataler GraphQL-Errors")
func opodoGraphQLKeepsTripsWhenErrorsAreNonFatal() throws {
    let json = """
    {"data":{"getTrips":{"trips":[{"trip":{
      "id":"h-1","tdToken":"FAKE_TOKEN_HOTEL","bookingStatus":"CONTRACT","bookingProductStatus":"CONFIRMED",
      "accommodationBooking":{"accommodationName":"Test Hotel","city":"Berlin","checkInDate":1785843900000,"checkOutDate":1786016700000}
    }}]}},
     "errors":[{"message":"Field warning"}]}
    """
    let page = try OpodoTripsGraphQLParser().parseTripPage(from: json)
    #expect(page.rawTripCount == 1)
    #expect(page.bookings.count == 1)
    #expect(page.bookings[0].bookingType == .hotel)
}

@Test("OpodoTripsGraphQLParser wirft GraphQL-Errors wenn keine Trip-Rows da sind")
func opodoGraphQLThrowsWhenErrorsAndNoTripRows() {
    let json = #"{"errors":[{"message":"Internal error"}]}"#
    #expect(throws: OpodoTripsGraphQLParserError.graphQLErrors("Internal error")) {
        try OpodoTripsGraphQLParser().parseTrips(from: json)
    }
}

private func fixtureJSON(_ name: String) throws -> String {
    try TestFixtures.text(name)
}
