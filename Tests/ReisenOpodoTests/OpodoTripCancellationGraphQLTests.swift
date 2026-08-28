import Testing
import Foundation
@testable import ReisenOpodo
import ReisenDomain

@Test("Opodo Status: CANCELLED vs CANCELLABLE")
func opodoCancellationStatusTokens() {
    #expect(BookingStatus.parseToken("CANCELLED") == .cancelled)
    #expect(BookingStatus.parseToken("BOOKING_CANCELLED") == .cancelled)
    #expect(BookingStatus.parseToken("CANCELLABLE") == .unknown)
    #expect(BookingStatus.parseToken("REFUNDABLE") == .unknown)
    #expect(
        BookingStatus.parse(parts: ["CONTRACT", "CONFIRMED", "CANCELLABLE"]) == .confirmed
    )
    #expect(BookingStatus.parse(parts: ["CANCELLED"]) == .cancelled)
    #expect(BookingStatus.parse("Storniert") == .cancelled)
    #expect(BookingStatus.parse("Stornierungsrichtlinie Bis 1. August") == .unknown)
}

@Test("Opodo Status: RETAINED/FINAL_RET sind Storno (HAR Hotel)")
func opodoRetainedIsCancelled() {
    // HAR: accommodationBooking.bookingStatus=RETAINED bei storniertem Hotel;
    // Trip-Ebene bleibt oft CONTRACT — Hotel-Status muss gewinnen.
    #expect(BookingStatus.parseToken("RETAINED") == .cancelled)
    #expect(BookingStatus.parseToken("FINAL_RET") == .cancelled)
    #expect(BookingStatus.parseToken("DIDNOTBUY") == .cancelled)
    #expect(BookingStatus.parse(parts: ["RETAINED"]) == .cancelled)
    #expect(BookingStatus.parse(parts: ["CONTRACT", "CANCELLED"]) == .cancelled)
}

@Test("OpodoWeb extrahiert tdToken aus Detail-URL")
func opodoTdTokenFromExternalURL() {
    let url = OpodoWeb.tripDetailsURL(token: "ABC_TOKEN_123")
    #expect(url.hasPrefix(OpodoWeb.secureAreaURLString))
    #expect(OpodoWeb.tdToken(fromExternalURL: url) == "ABC_TOKEN_123")
    #expect(OpodoWeb.tdToken(fromExternalURL: OpodoWeb.homepageURLString) == nil)
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
    #expect(BookingStatus.parse(parsed.statusRaw) != .cancelled)
    let free = try #require(parsed.deadlines.first { $0.isFreeCancellation })
    #expect(free.policyText?.contains("Cancellation policy") == true)
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
    #expect(free.policyText?.contains("Cancellation policy") == true)
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

@Test func opodoCancelledHotelEnrichmentDropsDeadlines() {
    let paid = CancellationDeadline(
        deadlineAt: Date(timeIntervalSince1970: 1_700_000_000),
        isFreeCancellation: false
    )
    let enrichment = OpodoHotelGraphQLEnrichment.make(
        statusRaw: "CANCELLED",
        deadlines: [paid],
        guestHints: []
    )
    #expect(enrichment.status == .cancelled)
    #expect(enrichment.deadlines.isEmpty)
    #expect(enrichment.guestHints == nil)
}