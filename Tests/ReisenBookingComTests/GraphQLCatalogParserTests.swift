import Testing
import Foundation
@testable import ReisenBookingCom
import ReisenDomain

@Test("BookingComTripsGraphQLParser parst Trip-IDs aus GetTripsQuery")
func bookingComParsesGetTripsIDs() throws {
    let json = try fixtureJSON("get_trips_compact.json")
    let ids = try BookingComTripsGraphQLParser().parseTripIDs(fromGetTripsJSON: json)
    #expect(ids.count == 3)
    #expect(ids.contains("306712048518231"))
    #expect(try BookingComTripsGraphQLParser().parsePaginationToken(fromGetTripsJSON: json) == nil)
}

@Test("BookingComTripsGraphQLParser parst Flug und Hotel aus SingleTimelineQuery")
func bookingComGraphQLParsesFlightAndHotel() throws {
    let json = try fixtureJSON("single_timeline_kuta_muenchen.json")
    let bookings = try BookingComTripsGraphQLParser().parseTimeline(from: json)

    #expect(bookings.count == 2)

    let byType = Dictionary(grouping: bookings, by: \.bookingType)
    #expect(byType[.flight]?.count == 1)
    #expect(byType[.hotel]?.count == 1)

    let flight = try #require(byType[.flight]?.first)
    #expect(flight.externalUrl?.contains("flights.booking.com") == true)
    #expect(flight.title == "Yogyakarta → Kuta")
    #expect(flight.locationFrom == "Yogyakarta (YIA)")
    #expect(flight.locationTo == "Kuta (DPS)")
    #expect(flight.status == .confirmed)
    #expect(flight.confirmationCode == "5031303168853001")
    #expect(flight.rateDetails?.totalPriceAmount == 229.55)
    #expect(flight.rateDetails?.totalPriceCurrency == "EUR")
    #expect(flight.rateDetails?.airline == "IU")
    #expect(flight.rateDetails?.passengerCount == 3)
    #expect(flight.deadlines.isEmpty)
    #expect(flight.flightDepartureOffsetSeconds == 7 * 3600)
    #expect(flight.flightArrivalOffsetSeconds == 8 * 3600)
    // Check24-Muster: Wanduhr als UTC + Offset → nach Normalizer Ortszeit 16:10 / 18:35
    var flightBooking = Booking(
        provider: .booking,
        bookingType: .flight,
        startAt: flight.startAt,
        endAt: flight.endAt,
        flightDepartureOffsetSeconds: flight.flightDepartureOffsetSeconds,
        flightArrivalOffsetSeconds: flight.flightArrivalOffsetSeconds
    )
    flightBooking.timesNormalized = false
    let normalizedFlight = BookingTimeNormalizer().normalizePendingIfPossible(flightBooking)
    let depTZ = TimeZone(secondsFromGMT: 7 * 3600)!
    let arrTZ = TimeZone(secondsFromGMT: 8 * 3600)!
    let depDF = DateFormatter()
    depDF.locale = Locale(identifier: "de_DE_POSIX")
    depDF.timeZone = depTZ
    depDF.dateFormat = "HH:mm"
    let arrDF = DateFormatter()
    arrDF.locale = Locale(identifier: "de_DE_POSIX")
    arrDF.timeZone = arrTZ
    arrDF.dateFormat = "HH:mm"
    #expect(depDF.string(from: normalizedFlight.startAt) == "16:10")
    #expect(arrDF.string(from: normalizedFlight.endAt) == "18:35")

    let hotel = try #require(byType[.hotel]?.first)
    #expect(hotel.externalUrl?.contains("booking.com") == true)
    #expect(hotel.title == "Hotel Am Nockherberg")
    #expect(hotel.locationTo == "München")
    #expect(hotel.locationToAddress == "Nockherstraße 38 A")
    #expect(hotel.confirmationCode == "6806647309")
    #expect(hotel.status == .confirmed)
    #expect(hotel.rateDetails?.totalPriceAmount == 135.15)
    #expect(hotel.rateDetails?.totalPriceCurrency == "EUR")
    #expect(hotel.rateDetails?.roomCount == 1)
    #expect(hotel.hotelOffsetSeconds == 2 * 3600)
    #expect(hotel.hotelCheckInMinutes == 15 * 60)
    #expect(hotel.hotelCheckOutMinutes == 11 * 60)
    // Grobe GraphQL-Frist (Fallback); Fee-Schedule kommt per Confirmation-Enrichment.
    #expect(hotel.deadlines.count == 1)
    let deadline = try #require(hotel.deadlines.first)
    #expect(deadline.isFreeCancellation == true)
    #expect(deadline.hotelOffsetSeconds == 2 * 3600)
    let hotelTZ = TimeZone(secondsFromGMT: 2 * 3600)!
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = hotelTZ
    let comps = cal.dateComponents([.day, .hour, .minute], from: deadline.deadlineAt)
    #expect(comps.day == 10)
    #expect(comps.hour == 23)
    #expect(comps.minute == 59)
}

@Test("BookingComParsing normalisiert confirmation.de.html → confirmation.html (HAR)")
func bookingComNormalizesHotelConfirmationURL() throws {
    let raw = "/confirmation.de.html?auth_key=OIGACKs01QJKxF38;aid=304142;source=mytrips"
    let normalized = try #require(BookingComParsing.normalizedHotelConfirmationURL(raw))
    #expect(normalized.contains("confirmation.html"))
    #expect(!normalized.lowercased().contains("confirmation.de.html"))
    #expect(normalized.contains("lang=de"))
    #expect(normalized.contains("auth_key=OIGACKs01QJKxF38"))
}

@Test("BookingComParsing normalisiert confirmation.en-us.html → confirmation.html lang=de")
func bookingComNormalizesEnUsHotelConfirmationURL() throws {
    // Live-DB 2026-07-20: Nockherberg-URL aus GraphQL bei en-us Session
    let raw = "https://secure.booking.com/confirmation.en-us.html?auth_key=OIGACKs01QJKxF38;aid=304142;source=mytrips"
    let normalized = try #require(BookingComParsing.normalizedHotelConfirmationURL(raw))
    #expect(normalized.hasPrefix("https://secure.booking.com/confirmation.html?"))
    #expect(!normalized.lowercased().contains("en-us"))
    #expect(normalized.contains("lang=de"))
    #expect(normalized.contains("auth_key=OIGACKs01QJKxF38"))
}

@Test("BookingComParsing parst englische exclusive Policy-Frist")
func bookingComParsesEnglishExclusivePolicyDate() throws {
    let offset = 2 * 3600
    let date = try #require(
        BookingComParsing.parseExclusiveGermanPolicyDate(
            in: "You can cancel this booking for free before Tue, Aug 11, 2026.",
            offsetSeconds: offset
        )
    )
    let tz = TimeZone(secondsFromGMT: offset)!
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tz
    let comps = cal.dateComponents([.day, .month, .hour, .minute], from: date)
    #expect(comps.day == 10)
    #expect(comps.month == 8)
    #expect(comps.hour == 23)
    #expect(comps.minute == 59)
}

@Test("Booking.com Mehrzimmer: price.amount ist Gesamtpreis der einen Reservierung")
func bookingComMultiRoomPriceIsReservationTotal() throws {
    let json = """
    {
      "data": {
        "singleTripTimelineQueries": {
          "singleTripTimeline": {
            "trip": { "title": "Nairobi" },
            "timelineGroups": [
              {
                "tripItems": [
                  {
                    "__typename": "ReservationTripItem",
                    "reservation": {
                      "__typename": "AccommodationReservation",
                      "verticalType": "ACCOMMODATION",
                      "bookingUrl": "/mybooking.de.html?auth_key=abc",
                      "reservationDetailsURL": "/mybooking.de.html?auth_key=abc",
                      "startDateTime": "2026-08-30T12:00:00.000+03:00",
                      "endDateTime": "2026-08-31T11:00:00.000+03:00",
                      "reservationStatus": "CONFIRMED",
                      "numOfRooms": 2,
                      "price": { "amount": 112.0, "currency": "EUR" },
                      "propertyData": {
                        "name": "Hemak Suites Hotel",
                        "location": { "city": "Nairobi" }
                      },
                      "identifiers": { "hotelReservationId": "4725097385", "publicId": "22-4725097385" }
                    }
                  }
                ]
              }
            ]
          }
        }
      }
    }
    """
    let bookings = try BookingComTripsGraphQLParser().parseTimeline(from: json)
    let hotel = try #require(bookings.first)
    #expect(bookings.count == 1)
    #expect(hotel.rateDetails?.roomCount == 2)
    #expect(hotel.rateDetails?.totalPriceAmount == 112.0)
    #expect(hotel.rateDetails?.totalPriceCurrency == "EUR")
}

@Test("BookingComTripsGraphQLParser erkennt TripsListError und GraphQL-Errors")
func bookingComGetTripsRejectsErrors() {
    let listError = #"{"data":{"tripsQueries":{"getTrips":{"__typename":"TripsListError","statusCode":401,"response":"x"}}}}"#
    #expect(throws: BookingComTripsGraphQLParserError.tripsListError) {
        _ = try BookingComTripsGraphQLParser().parseTripIDs(fromGetTripsJSON: listError)
    }
    let gqlError = #"{"errors":[{"message":"boom"}],"data":null}"#
    #expect(throws: BookingComTripsGraphQLParserError.graphQLErrors("boom")) {
        _ = try BookingComTripsGraphQLParser().parseTripIDs(fromGetTripsJSON: gqlError)
    }
}

@Test("Timeline-Query: address nur über AccommodationLocation-Fragment (HAR)")
func bookingComTimelineQueryRequestsAddressViaFragment() throws {
    // Regression: `location { address }` ohne Inline-Fragment → GraphQL-Validierungsfehler für alle Trips.
    let sourceURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/ReisenBookingCom/BookingComTravelProvider.swift")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    #expect(source.contains("... on AccommodationLocation"))
    #expect(source.contains("... on ReservationPropertyData"))
    #expect(!source.contains("location { city address __typename }"))
}

@Test("BookingComTripsGraphQLParser liefert leere Liste ohne Timeline-Gruppen")
func bookingComGraphQLReturnsEmptyWhenNoTimelines() throws {
    let json = #"{"data":{"singleTripTimelineQueries":{"singleTripTimeline":{"trip":{"title":"X"},"timelineGroups":[]}}}}"#
    let bookings = try BookingComTripsGraphQLParser().parseTimeline(from: json)
    #expect(bookings.isEmpty)
}

@Test("BookingComSessionTokens extrahiert CSRF und Trip-XP Client-Version")
func bookingComSessionTokensFromHTML() throws {
    let html = """
    <div data-capla-namespace="b-trips-frontend-trip-xp-mfeYTObNTBd"></div>
    <script>{"csrfToken":"eyJhbGciOiJIUzUxMiJ9.eyJpc3MiOiJjb250ZXh0LWVucmljaG1lbnQtYXBpIiwic3ViIjoiY3NyZi10b2tlbiJ9.sig"}</script>
    """
    let tokens = try BookingComSessionTokens.extract(from: html)
    #expect(tokens.csrfToken.hasPrefix("eyJ"))
    #expect(tokens.apolloClientVersion == "YTObNTBd")
}

@Test("BookingComSessionTokens akzeptiert Wishlist-MFE als Fallback")
func bookingComSessionTokensWishlistFallback() throws {
    let html = """
    <div data-capla-namespace="b-wishlist-wishlist-mfeEQdVaEPZ"></div>
    <script>{"csrfToken":"eyJhbGciOiJIUzUxMiJ9.eyJpc3MiOiJjb250ZXh0LWVucmljaG1lbnQtYXBpIiwic3ViIjoiY3NyZi10b2tlbiJ9.sig"}</script>
    """
    let tokens = try BookingComSessionTokens.extract(from: html)
    #expect(tokens.apolloClientVersion == "EQdVaEPZ")
}

@Test("BookingComHotelConfirmationParser liest Zimmer, Gäste und Frühstück")
func bookingComHotelConfirmationParsesRateDetails() throws {
    let html = try fixtureText("hotel_confirmation_sample.html")
    let rate = try #require(BookingComHotelConfirmationParser().parseRateDetails(from: html))
    #expect(rate.roomCategory == "Zweibettzimmer")
    #expect(rate.guestCount == 2)
    #expect(rate.includedBreakfast == true)
    #expect(rate.boardType == .breakfastIncluded)
}

@Test("BookingComFlightOrderParser liefert Gepäck und TZ-Offsets")
func bookingComFlightOrderParsesBaggageAndOffsets() throws {
    let json = try fixtureJSON("flight_order_sample.json")
    let parsed = try BookingComFlightOrderParser().parse(from: json)
    #expect(parsed.deadlines.isEmpty)
    #expect(parsed.flightDepartureOffsetSeconds == 7 * 3600)
    #expect(parsed.flightArrivalOffsetSeconds == 8 * 3600)
    #expect(parsed.rateDetails?.baggageInfoRaw?.contains("Aufgabe") == true)
    #expect(parsed.rateDetails?.baggageInfoRaw?.contains("10KG") == true)
    #expect(parsed.rateDetails?.baggageInfoRaw?.contains("Hand") == true)
    #expect(parsed.passengers.isEmpty == true)
}

@Test("BookingComFlightOrderParser parst strukturierte Passagiere + Gepäck")
func bookingComFlightOrderParsesPassengersAndBaggage() throws {
    // Minimaler Ausschnitt wie in den flights.booking.com Order-Responses (HAR).
    let json = """
    {
      "cancellationOptions": {
        "cancellable": false,
        "isFullRefund": false,
        "refundOptions": [],
        "cancellationStatus": "UNKNOWN_CANCELLABLE",
        "flightsPbemUniversalNonRefundableOrders": false
      },
      "airOrder": {
        "flightSegments": [
          {
            "departureTimeTz": "2026-08-11T16:10:00+07:00",
            "arrivalTimeTz": "2026-08-11T18:35:00+08:00",
            "travellerCheckedLuggage": [
              {
                "travellerReference": "T1",
                "luggageAllowance": {
                  "luggageType": "CHECKED_IN",
                  "ruleType": "PIECE_BASED",
                  "maxPiece": 1,
                  "maxWeightPerPiece": 10,
                  "massUnit": "KG"
                }
              }
            ],
            "travellerCabinLuggage": [
              {
                "travellerReference": "T1",
                "luggageAllowance": {
                  "luggageType": "HAND",
                  "maxPiece": 1,
                  "maxWeightPerPiece": 5,
                  "massUnit": "KG",
                  "sizeRestrictions": { "maxLength": 40, "maxWidth": 30, "maxHeight": 20, "sizeUnit": "CM" }
                },
                "personalItem": true
              }
            ]
          }
        ]
      },
      "passengers": [
        { "travellerReference": "T1", "firstName": "Roland", "lastName": "Schramme", "type": "ADULT" }
      ]
    }
    """

    let parsed = try BookingComFlightOrderParser().parse(from: json)
    #expect(parsed.passengers.count == 1)
    let pax = try #require(parsed.passengers.first)
    #expect(pax.givenName == "Roland")
    #expect(pax.familyName == "Schramme")
    #expect(pax.travellerType == .adult)
    #expect(pax.baggageAllowances.contains { $0.type == .checkedBag && $0.pieceCount == 1 && $0.weightKg == 10 })
    #expect(pax.baggageAllowances.contains { $0.type == .cabinBag && $0.pieceCount == 1 && $0.weightKg == 5 })
    #expect(pax.baggageAllowances.contains { $0.type == .personalItem && $0.pieceCount == 1 })
}

@Test("Fixture-Katalog setzt Flug-Offsets aus ISO-Zeiten")
func bookingComFixtureSetsFlightOffsetsFromISO() throws {
    let json = try fixtureJSON("single_timeline_kuta_muenchen.json")
    let flight = try #require(
        BookingComTripsGraphQLParser().parseTimeline(from: json).first { $0.bookingType == .flight }
    )
    #expect(flight.flightDepartureOffsetSeconds == 7 * 3600)
    #expect(flight.flightArrivalOffsetSeconds == 8 * 3600)
}

@Test("BookingComTravelProvider extrahiert Order-Token aus Confirmation-URL")
func bookingComFlightOrderTokenFromURL() throws {
    let url = URL(string: "https://flights.booking.com/confirmation/abc123token?x=1")!
    #expect(BookingComTravelProvider.flightOrderToken(from: url) == "abc123token")
}

@Test("My-Trips-HTML mit Marketing-Copy liefert trotzdem trip_id (HAR-Regression)")
func bookingComTripIDsFromMyTripsHTMLDespiteEmptyMarketingCopy() {
    // HAR 2026-07-20: Diese Strings stehen auch auf Seiten MIT Reisen im DOM.
    let html = """
    <html><body>
      <p>Wohin geht es als Nächstes</p>
      <p>Sie haben noch keine Reisen begonnen</p>
      <a href="https://secure.booking.com/mytrips.de.html?trip_id=303612277422833">Kuta und München</a>
      <a href="https://secure.booking.com/mytrips.de.html?trip_id=303612277422833">dup</a>
    </body></html>
    """
    let ids = BookingComTravelProvider.tripIDsFromMyTripsHTML(html)
    #expect(ids == ["303612277422833"])
}

@Test("My-Trips-HTML ohne trip_id gilt als leerer Katalog-Hinweis")
func bookingComTripIDsFromMyTripsHTMLEmptyWhenNoTripLinks() {
    let html = "<html><body><p>Wohin geht es als Nächstes</p></body></html>"
    #expect(BookingComTravelProvider.tripIDsFromMyTripsHTML(html).isEmpty)
}

private func fixtureJSON(_ name: String) throws -> String {
    try fixtureText(name)
}

private func fixtureText(_ name: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
    return try String(contentsOf: url, encoding: .utf8)
}
