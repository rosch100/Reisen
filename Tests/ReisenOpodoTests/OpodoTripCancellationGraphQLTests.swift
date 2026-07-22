import Testing
import Foundation
import ReisenOpodo
import ReisenDomain

@Test("Opodo Status: CANCELLED vs CANCELLABLE")
func opodoCancellationStatusTokens() {
    #expect(OpodoTripCancellationGraphQLParser.isCancelledStatusToken("CANCELLED"))
    #expect(OpodoTripCancellationGraphQLParser.isCancelledStatusToken("BOOKING_CANCELLED"))
    #expect(!OpodoTripCancellationGraphQLParser.isCancelledStatusToken("CANCELLABLE"))
    #expect(!OpodoTripCancellationGraphQLParser.isCancelledStatusToken("REFUNDABLE"))
    #expect(
        OpodoTripCancellationGraphQLParser.status(
            bookingStatus: "CONTRACT",
            productStatus: "CONFIRMED",
            cancellableStatus: "CANCELLABLE"
        ) == nil
    )
    #expect(
        OpodoTripCancellationGraphQLParser.status(
            bookingStatus: "CANCELLED",
            productStatus: nil,
            cancellableStatus: nil
        ) == .cancelled
    )
    #expect(OpodoTripCancellationGraphQLParser.looksCancelled(inPageText: "Status\nStorniert\nHotel"))
    #expect(!OpodoTripCancellationGraphQLParser.looksCancelled(inPageText: "Stornierungsrichtlinie Bis 1. August"))
}

@Test("Opodo Status: RETAINED/FINAL_RET sind Storno (HAR Hotel)")
func opodoRetainedIsCancelled() {
    // HAR: accommodationBooking.bookingStatus=RETAINED bei storniertem Hotel;
    // Trip-Ebene bleibt oft CONTRACT — Hotel-Status muss gewinnen.
    #expect(OpodoTripCancellationGraphQLParser.isCancelledStatusToken("RETAINED"))
    #expect(OpodoTripCancellationGraphQLParser.isCancelledStatusToken("FINAL_RET"))
    #expect(OpodoTripCancellationGraphQLParser.isCancelledStatusToken("DIDNOTBUY"))
    #expect(
        OpodoTripCancellationGraphQLParser.status(
            bookingStatus: "RETAINED",
            productStatus: nil,
            cancellableStatus: nil
        ) == .cancelled
    )
    #expect(
        OpodoTripCancellationGraphQLParser.status(
            bookingStatus: "CONTRACT",
            productStatus: "CANCELLED",
            cancellableStatus: nil
        ) == .cancelled
    )
}

@Test("OpodoGetTripByTokenQuery extrahiert tdToken aus Detail-URL")
func opodoTdTokenFromExternalURL() {
    let url = "https://www.opodo.de/travel/secure/#tripdetails/td=ABC_TOKEN_123"
    #expect(OpodoGetTripByTokenQuery.tdToken(fromExternalURL: url) == "ABC_TOKEN_123")
    #expect(OpodoGetTripByTokenQuery.tdToken(fromExternalURL: "https://www.opodo.de/") == nil)
}

@Test("OpodoTripCancellationGraphQLParser liest Hotel- und Flug-Storno")
func opodoCancellationGraphQLParsesHotelAndFlight() throws {
    let json = """
    {
      "data": {
        "getTrip": {
          "trip": {
            "id": "1",
            "itinerary": {
              "freeCancellation": "2026-08-01T10:00:00Z",
              "freeCancellationLimit": { "limitTime": 1785566400000, "hoursApart": 48 }
            },
            "accommodationBooking": {
              "cancellationDate": "2026-08-05T12:00:00+02:00",
              "roomsGroupCancelPolicy": null,
              "bookingCancelPolicy": null,
              "accommodationCancelPolicy": null,
              "cancellationInformation": {
                "cancellableStatus": "CANCELLABLE",
                "cancellationOptions": [
                  {
                    "from": "2026-07-01T00:00:00Z",
                    "until": "2026-08-03T21:59:00Z",
                    "refundAmount": { "amount": 100.0, "currency": "EUR" },
                    "refundPercentage": 100
                  }
                ]
              },
              "cancellationPolicies": {
                "cancellableStatus": "CANCELLABLE",
                "cancellationOptions": []
              }
            }
          }
        }
      }
    }
    """

    let deadlines = try OpodoTripCancellationGraphQLParser().parseDeadlines(from: json)
    #expect(deadlines.count >= 2)
    #expect(deadlines.contains { $0.isFreeCancellation })
}

@Test("OpodoTripCancellationGraphQLParser nimmt bei Hotel das späteste 100%-Fenster")
func opodoCancellationGraphQLPrefersLatestFreeHotelOption() throws {
    let json = """
    {
      "data": {
        "getTrip": {
          "trip": {
            "id": "1",
            "itinerary": null,
            "accommodationBooking": {
              "cancellationDate": null,
              "roomsGroupCancelPolicy": null,
              "bookingCancelPolicy": null,
              "accommodationCancelPolicy": null,
              "cancellationInformation": {
                "cancellableStatus": "CANCELLABLE",
                "cancellationOptions": [
                  {
                    "from": "2026-07-01T00:00:00Z",
                    "until": "2026-07-27T00:00:00Z",
                    "refundAmount": { "amount": 100.0, "currency": "EUR" },
                    "refundPercentage": 100
                  },
                  {
                    "from": "2026-07-01T00:00:00Z",
                    "until": "2026-08-01T22:00:00Z",
                    "refundAmount": { "amount": 100.0, "currency": "EUR" },
                    "refundPercentage": 100
                  }
                ]
              },
              "cancellationPolicies": { "cancellableStatus": "CANCELLABLE", "cancellationOptions": [] }
            }
          }
        }
      }
    }
    """
    let deadlines = try OpodoTripCancellationGraphQLParser().parseDeadlines(from: json)
    #expect(deadlines.count == 1)
    let deadline = try #require(deadlines.first)
    #expect(deadline.isFreeCancellation == true)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let comps = calendar.dateComponents([.month, .day], from: deadline.deadlineAt)
    #expect(comps.month == 8)
    #expect(comps.day == 1)
}

@Test("OpodoTripCancellationGraphQLParser liest Merlynn-Hotel-Policy aus HAR 2026-07-20")
func opodoCancellationGraphQLReadsMerlynnHARPolicies() throws {
    let json = """
    {
      "data": {
        "getTrip": {
          "trip": {
            "bookingStatus": "CONTRACT",
            "bookingProductStatus": "CONFIRMED",
            "accommodationBooking": { "bookingStatus": "CONTRACT" },
            "accommodationProductBooking": {
              "cancellationPolicies": {
                "cancellableStatus": "REFUNDABLE",
                "cancellationOptions": [
                  {
                    "from": "2026-07-18T12:00:00+02:00",
                    "until": "2026-08-17T05:59:00+02:00",
                    "refundAmount": { "amount": 63.0, "currency": "EUR" },
                    "refundPercentage": 100
                  },
                  {
                    "from": "2026-08-17T06:00:00+02:00",
                    "until": "2026-08-21T00:00:00+02:00",
                    "refundAmount": { "amount": 0.0, "currency": "EUR" },
                    "refundPercentage": 0
                  }
                ]
              }
            }
          }
        }
      }
    }
    """
    let parsed = try OpodoTripCancellationGraphQLParser().parse(from: json)
    #expect(parsed.status == nil)
    let free = try #require(parsed.deadlines.first { $0.isFreeCancellation })
    #expect(free.policyText?.contains("Stornierungsrichtlinie") == true)
    #expect(free.hotelOffsetSeconds == 2 * 3600)

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 2 * 3600)!
    let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: free.deadlineAt)
    #expect(comps.year == 2026)
    #expect(comps.month == 8)
    #expect(comps.day == 17)
    #expect(comps.hour == 5)
    #expect(comps.minute == 59)
}

@Test("OpodoTripCancellationGraphQLParser liest HAR-Feld accommodationProductBooking")
func opodoCancellationGraphQLReadsProductBookingPolicies() throws {
    // HAR 2026-07-18: until mit explizitem -00:00 → Anzeige 1.8. 22:00, nicht CEST 2.8. 00:00.
    let json = """
    {
      "data": {
        "getTrip": {
          "trip": {
            "id": "25314675162",
            "itinerary": null,
            "accommodationProductBooking": {
              "cancellationPolicies": {
                "cancellableStatus": "REFUNDABLE",
                "cancellationOptions": [
                  {
                    "from": "2026-07-08T13:53:39.682046-00:00",
                    "until": "2026-08-01T22:00:00-00:00",
                    "refundAmount": { "amount": 207.0, "currency": "EUR" },
                    "refundPercentage": 100
                  },
                  {
                    "from": "2026-08-01T22:00:00-00:00",
                    "until": "2026-08-11T12:00:00-00:00",
                    "refundAmount": { "amount": 0.0, "currency": "EUR" },
                    "refundPercentage": 0
                  }
                ]
              }
            },
            "accommodationBooking": {
              "cancellationDate": null,
              "roomsGroupCancelPolicy": null,
              "bookingCancelPolicy": null,
              "accommodationCancelPolicy": null,
              "cancellationInformation": {
                "cancellableStatus": "CANCELLABLE",
                "cancellationOptions": []
              },
              "cancellationPolicies": {
                "cancellableStatus": "CANCELLABLE",
                "cancellationOptions": []
              }
            }
          }
        }
      }
    }
    """
    let deadlines = try OpodoTripCancellationGraphQLParser().parseDeadlines(from: json)
    #expect(deadlines.contains { $0.isFreeCancellation })
    let free = try #require(deadlines.first { $0.isFreeCancellation })
    #expect(free.policyText?.contains("Stornierungsrichtlinie") == true)
    #expect(free.hotelOffsetSeconds == 0)

    let tz = TimeZone(secondsFromGMT: free.hotelOffsetSeconds ?? 0)!
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = tz
    let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: free.deadlineAt)
    #expect(comps.year == 2026)
    #expect(comps.month == 8)
    #expect(comps.day == 1)
    #expect(comps.hour == 22)
    #expect(comps.minute == 0)

    // Gegenprobe: in CEST wäre es 2.8. 00:00 — darf nicht die Anzeige-Zone sein.
    var cest = Calendar(identifier: .gregorian)
    cest.timeZone = TimeZone(secondsFromGMT: 2 * 3600)!
    let cestComps = cest.dateComponents([.day, .hour], from: free.deadlineAt)
    #expect(cestComps.day == 2)
    #expect(cestComps.hour == 0)
}