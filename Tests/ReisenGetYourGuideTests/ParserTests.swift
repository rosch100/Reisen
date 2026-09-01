import Testing
import Foundation
import ReisenDomain
import ReisenProviders
@testable import ReisenGetYourGuide

@Test("GetYourGuideMyBookingsParser mappt upcomingBookings zu .activity Drafts")
func gygMyBookingsParsesUpcomingActivityDrafts() throws {
    let json = try GetYourGuideResearchFixture.json(named: "gyg_myBookings_redacted.json")
    let catalog = try GetYourGuideMyBookingsParser.parse(from: json)

    #expect(catalog.bookings.count == 2)
    #expect(Set(catalog.bookings.map(\.status)) == [.confirmed])
    let draft = try #require(catalog.bookings.first {
        $0.externalUrl == GetYourGuideWebConstants.bookingURL(hash: "<REDACTED-1>")
    })

    #expect(draft.provider == .getYourGuide)
    #expect(draft.bookingType == .activity)
    #expect(draft.status == .confirmed)
    #expect(draft.title == "Yogyakarta: Ramayana Ballett Prambanan")
    #expect(draft.confirmationCode == "<REDACTED>")
    #expect(draft.startAt == iso8601("2026-08-08T19:00:00+07:00"))
    #expect(draft.endAt == iso8601("2026-08-08T21:00:00+07:00"))
    #expect(draft.locationTo == "<REDACTED>")
    #expect(draft.rateDetails?.totalPriceAmount == 53.94)
    #expect(draft.rateDetails?.totalPriceCurrency == "EUR")
    #expect(draft.rateDetails?.guestCount == 3)
    #expect(draft.rateDetails?.passengerCount == nil)

    #expect(draft.deadlines.count == 1)
    let deadline = try #require(draft.deadlines.first)
    #expect(deadline.deadlineAt == iso8601("2026-08-07T19:00:00+07:00"))
    #expect(deadline.isFreeCancellation == true)
    #expect(deadline.policyText?.contains("vollständige Rückerstattung") == true)
    #expect(draft.cancellationUrl == draft.externalUrl)
    #expect(draft.cancellationUrl == GetYourGuideWebConstants.bookingURL(hash: "<REDACTED-1>"))
}

@Test("GetYourGuideMyBookingsParser mappt pastBookings ohne Pagination-Keys")
func gygMyBookingsParsesPastWhenUpcomingEmpty() throws {
    let json = try GetYourGuideResearchFixture.json(named: "gyg_myBookings_ssr_lists_redacted.json")
    let catalog = try GetYourGuideMyBookingsParser.parse(from: json)
    #expect(catalog.bookings.count == 1)
    let draft = try #require(catalog.bookings.first)
    #expect(draft.status == .confirmed)
    #expect(draft.externalUrl == GetYourGuideWebConstants.bookingURL(hash: "<REDACTED>"))
    #expect(draft.cancellationUrl == draft.externalUrl)
    #expect(draft.startAt == iso8601("2026-08-08T19:00:00+07:00"))
    #expect(draft.endAt == iso8601("2026-08-08T21:00:00+07:00"))
}

@Test("Live myBookings-Shape hat keine Pagination-Keys")
func gygLiveMyBookingsShapeHasNoPaginationKeys() throws {
    let json = try GetYourGuideResearchFixture.json(named: "gyg_myBookings_ssr_lists_redacted.json")
    let root = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    let myBookings = try #require(root["myBookings"] as? [String: Any])
    for key in ["page", "offset", "cursor", "hasMore", "pageSize", "loadMore"] {
        #expect(myBookings[key] == nil, "unerwarteter Pagination-Key \(key)")
    }
    #expect(myBookings["upcomingBookings"] != nil)
    #expect(myBookings["pastBookings"] != nil)
}

@Test("GetYourGuideMyBookingsParser dedupliziert dieselbe Buchung in upcoming und past")
func gygMyBookingsDedupesUpcomingAndPastByHash() throws {
    let json = """
    {"myBookings":{"upcomingBookings":[\(gygListBookingJSON(hash: "abc", status: "active"))],\
    "pastBookings":[\(gygListBookingJSON(hash: "abc", status: "active"))]}}
    """
    let catalog = try GetYourGuideMyBookingsParser.parse(from: json)
    #expect(catalog.bookings.count == 1)
}

@Test("GetYourGuideMyBookingsParser behält past, wenn upcoming mit gleichem Hash nicht mappbar ist")
func gygMyBookingsKeepsPastWhenUpcomingSameHashDoesNotMap() throws {
    let json = """
    {"myBookings":{"upcomingBookings":[\
    \(gygListBookingJSON(hash: "same", status: "done")),\
    \(gygListBookingJSON(hash: "nofin", status: "active", finish: nil))\
    ],"pastBookings":[\
    \(gygListBookingJSON(hash: "same", status: "active")),\
    \(gygListBookingJSON(hash: "nofin", status: "cancelled"))\
    ]}}
    """
    let catalog = try GetYourGuideMyBookingsParser.parse(from: json)
    #expect(catalog.bookings.map(\.status) == [.confirmed])
    #expect(catalog.bookings.map(\.externalUrl) == [
        GetYourGuideWebConstants.bookingURL(hash: "same"),
    ])
}

@Test("GetYourGuideMyBookingsParser droppt cancelled über CatalogListing.shouldDrop")
func gygMyBookingsDropsCancelledPast() throws {
    let json = """
    {"myBookings":{"upcomingBookings":[],"pastBookings":[\(gygListBookingJSON(hash: "cx", status: "cancelled"))]}}
    """
    let catalog = try GetYourGuideMyBookingsParser.parse(from: json)
    #expect(catalog.bookings.isEmpty)
}

@Test("GetYourGuideMyBookingsParser überspringt Einträge ohne bookingFinishDate")
func gygMyBookingsSkipsEntryWithoutFinishDateAndKeepsOthers() throws {
    let json = """
    {
      "myBookings": {
        "upcomingBookings": [
          {
            "bookingHash": "keep",
            "bookingReference": "keep-ref",
            "status": "active",
            "startingTime": { "startTime": "2026-08-08T19:00:00+07:00" },
            "bookingFinishDate": "2026-08-08T21:00:00+07:00"
          },
          {
            "bookingHash": "skip-end",
            "bookingReference": "skip-ref",
            "status": "active",
            "startingTime": { "startTime": "2026-08-09T19:00:00+07:00" }
          }
        ]
      }
    }
    """
    let catalog = try GetYourGuideMyBookingsParser.parse(from: json)
    #expect(catalog.bookings.map(\.confirmationCode) == ["keep-ref"])
}

@Test("GetYourGuideMyBookingsParser überspringt done- und ended-Status")
func gygMyBookingsSkipsCompletedStatusAndKeepsOthers() throws {
    let json = """
    {
      "myBookings": {
        "upcomingBookings": [
          {
            "bookingHash": "keep",
            "bookingReference": "keep-ref",
            "status": "active",
            "startingTime": { "startTime": "2026-08-08T19:00:00+07:00" },
            "bookingFinishDate": "2026-08-08T21:00:00+07:00"
          },
          {
            "bookingHash": "skip-done",
            "bookingReference": "skip-ref",
            "status": "done",
            "startingTime": { "startTime": "2026-08-09T19:00:00+07:00" },
            "bookingFinishDate": "2026-08-09T21:00:00+07:00"
          },
          {
            "bookingHash": "skip-ended",
            "bookingReference": "skip-ended-ref",
            "status": "ended",
            "startingTime": { "startTime": "2026-08-10T19:00:00+07:00" },
            "bookingFinishDate": "2026-08-10T21:00:00+07:00"
          }
        ]
      }
    }
    """
    let catalog = try GetYourGuideMyBookingsParser.parse(from: json)
    #expect(catalog.bookings.map(\.confirmationCode) == ["keep-ref"])
}

@Test("GetYourGuideInitialState erkennt Cloudflare-Challenge-HTML")
func gygInitialStateDetectsCloudflareChallenge() {
    let challenge = GetYourGuideResearchFixture.cloudflareChallengeHTML
    #expect(GetYourGuideInitialState.looksLikeCloudflareChallenge(challenge))
    #expect(!GetYourGuideInitialState.looksLikeCloudflareChallenge(GetYourGuideResearchFixture.initialStateHTML("{}")))
}

@Test("GetYourGuideProviderError: fehlende Session nach Login-HTML")
func gygProviderErrorSessionNotEstablished() {
    let error = GetYourGuideProviderError.sessionNotEstablished
    #expect(error.errorDescription?.contains("Session") == true)
    #expect(GetYourGuideProviderError.from(.notEstablished) == .sessionNotEstablished)
    #expect(GetYourGuideProviderError.from(.challenge) == .cloudflareChallenge)
}

@Test("GetYourGuideBookingSummaryParser mappt Treffpunkt, Fristen und Teilnehmer ohne PII-Namen")
func gygBookingSummaryParsesEnrichment() throws {
    let json = try GetYourGuideResearchFixture.json(named: "gyg_bookingSummary_redacted.json")
    let enrichment = try GetYourGuideBookingSummaryParser.parse(from: json)

    #expect(enrichment.status == .confirmed)
    #expect(enrichment.title == "Yogyakarta: Ramayana Ballett Prambanan")
    #expect(enrichment.locationTo == "<REDACTED>")
    #expect(enrichment.locationToAddress == "<REDACTED>")

    #expect(enrichment.deadlines.count == 1)
    let deadline = try #require(enrichment.deadlines.first)
    #expect(deadline.deadlineAt == iso8601("2026-08-07T19:00:00+07:00"))
    #expect(deadline.isFreeCancellation == true)

    #expect(enrichment.rateDetails?.totalPriceAmount == 53.94)
    #expect(enrichment.rateDetails?.totalPriceCurrency == "EUR")
    #expect(enrichment.rateDetails?.roomCategory == "Tickets der 2. Klasse")
    #expect(enrichment.rateDetails?.guestCount == 3)
    #expect(enrichment.rateDetails?.passengerCount == nil)

    let passengers = try #require(enrichment.passengers)
    #expect(passengers.count == 3)
    #expect(passengers.allSatisfy { $0.travellerType == .adult })
    #expect(passengers.allSatisfy { $0.givenName == nil && $0.familyName == nil })
    #expect(passengers.first?.title == "Erwachsene")

    let hints = try #require(enrichment.guestHints)
    #expect(hints.contains { $0.sourceKey == "gyg:meetingPoint" })
    #expect(hints.contains { $0.sourceKey.hasPrefix("gyg:restriction:") })
    #expect(hints.contains { $0.sourceKey == "gyg:inclusions" })
    #expect(hints.contains { $0.sourceKey == "gyg:mobileVoucher" })
    #expect(hints.contains { $0.sourceKey.hasPrefix("gyg:itinerary:") })
}

@Test("GetYourGuideBookingSummaryParser setzt keine Teilnehmerzeilen bei unvollständiger Occupancy")
func gygBookingSummaryOmitsPassengersWhenAnyParticipantCountMissing() throws {
    let json = """
    {"bookingSummary":{"booking":{"status":"active",\
    "price":{"amount":10,"currencyIsoCode":"EUR"},\
    "activityParticipants":[\
    {"count":2,"priceCategoryLabel":"adult","description":"Erwachsene"},\
    {"priceCategoryLabel":"child"}\
    ]}}}
    """
    let enrichment = try GetYourGuideBookingSummaryParser.parse(from: json)
    #expect(enrichment.rateDetails?.guestCount == nil)
    #expect(enrichment.rateDetails?.passengerCount == nil)
    #expect(enrichment.passengers == nil)
}

@Test("GetYourGuideMyBookingsParser setzt Occupancy nicht bei unvollständiger Teilnehmerzahl")
func gygMyBookingsOmitsOccupancyWhenAnyParticipantCountMissing() throws {
    let json = """
    {"upcomingBookings":[\
    {"bookingHash":"no-count","bookingReference":"REF1","status":"active",\
    "startingTime":{"startTime":"2026-08-08T19:00:00+07:00"},\
    "bookingFinishDate":"2026-08-08T21:00:00+07:00",\
    "price":{"amount":10,"currencyIsoCode":"EUR"},\
    "activityParticipants":[\
    {"count":2,"priceCategoryLabel":"adult"},\
    {"priceCategoryLabel":"child"}\
    ],\
    "bookedOption":{"activityTitle":"T"}}]}
    """
    let catalog = try GetYourGuideMyBookingsParser.parse(from: json)
    let draft = try #require(catalog.bookings.first)
    #expect(draft.rateDetails?.totalPriceAmount == 10)
    #expect(draft.rateDetails?.guestCount == nil)
    #expect(draft.rateDetails?.passengerCount == nil)
}

@Test("GetYourGuideMyBookingsParser setzt Occupancy auch ohne Preis")
func gygMyBookingsKeepsOccupancyWithoutPrice() throws {
    let json = """
    {"upcomingBookings":[\
    {"bookingHash":"occ","bookingReference":"REF1","status":"active",\
    "startingTime":{"startTime":"2026-08-08T19:00:00+07:00"},\
    "bookingFinishDate":"2026-08-08T21:00:00+07:00",\
    "activityParticipants":[{"count":2,"priceCategoryLabel":"adult"}],\
    "bookedOption":{"activityTitle":"T"}}]}
    """
    let catalog = try GetYourGuideMyBookingsParser.parse(from: json)
    let draft = try #require(catalog.bookings.first)
    #expect(draft.rateDetails?.totalPriceAmount == nil)
    #expect(draft.rateDetails?.guestCount == 2)
}

@Test("GetYourGuideMyBookingsParser überspringt Draft ohne bookingHash")
func gygMyBookingsSkipsDraftWithoutHash() throws {
    let json = """
    {
      "upcomingBookings": [
        {
          "status": "active",
          "bookingReference": "REF-ONLY",
          "startingTime": { "startTime": "2099-08-08T19:00:00+07:00" },
          "bookingFinishDate": "2099-08-08T21:00:00+07:00",
          "bookedOption": { "activityTitle": "Ohne Hash" }
        }
      ]
    }
    """
    let catalog = try GetYourGuideMyBookingsParser.parse(from: json)
    #expect(catalog.bookings.isEmpty)
}

@Test("GetYourGuide Catalog-Drafts haben browserURL")
func gygCatalogDraftsHaveBrowserURL() throws {
    let json = try GetYourGuideResearchFixture.json(named: "gyg_myBookings_redacted.json")
    let catalog = try GetYourGuideMyBookingsParser.parse(from: json)
    for draft in catalog.bookings {
        #expect(BookingExternalURL.browserURL(from: draft.externalUrl) != nil)
    }
}

@Test("GetYourGuideInitialState extrahiert JSON-Objekt per Brace-Scan")
func gygInitialStateExtractsBalancedJSON() throws {
    let payload = #"{"myBookings":{"upcomingBookings":[]}}"#
    let html = GetYourGuideResearchFixture.initialStateHTML(payload)
    let extracted = try #require(GetYourGuideInitialState.extractJSONObject(fromHTML: html))
    #expect(extracted == payload)

    let nested = #"{"a":{"b":"}"},"c":1}"#
    let nestedHTML = "prefix \(GetYourGuideInitialState.marker) = \(nested) // trailing"
    #expect(GetYourGuideInitialState.extractJSONObject(fromHTML: nestedHTML) == nested)
}

private func iso8601(_ value: String) -> Date {
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withInternetDateTime]
    return fmt.date(from: value)!
}

private func gygListBookingJSON(hash: String?, status: String, finish: String? = "2026-08-08T21:00:00+07:00") -> String {
    let hashJSON = hash.map { "\"\($0)\"" } ?? "null"
    let finishJSON = finish.map { "\"\($0)\"" } ?? "null"
    return """
    {"bookingHash":\(hashJSON),"bookingReference":"REF1","status":"\(status)",\
    "startingTime":{"startTime":"2026-08-08T19:00:00+07:00","startTimeType":"datetime"},\
    "bookingFinishDate":\(finishJSON),\
    "bookedOption":{"activityTitle":"T","activityLocation":{"city":{"name":"C"}}}}
    """
}
