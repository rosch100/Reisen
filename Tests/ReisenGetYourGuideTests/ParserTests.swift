import Testing
import Foundation
import ReisenDomain
@testable import ReisenGetYourGuide

@Test("GetYourGuideMyBookingsParser mappt upcomingBookings zu .activity Drafts")
func gygMyBookingsParsesUpcomingActivityDrafts() throws {
    let json = try GetYourGuideResearchFixture.json(named: "gyg_myBookings_redacted.json")
    let catalog = try GetYourGuideMyBookingsParser.parse(from: json)

    #expect(catalog.bookings.count == 1)
    let draft = try #require(catalog.bookings.first)

    #expect(draft.provider == .getYourGuide)
    #expect(draft.bookingType == .activity)
    #expect(draft.status == .confirmed)
    #expect(draft.title == "Yogyakarta: Ramayana Ballett Prambanan")
    #expect(draft.confirmationCode == "<REDACTED>")
    #expect(draft.externalUrl == "https://www.getyourguide.com/en-us/booking/<REDACTED>")
    #expect(draft.startAt == iso8601("2026-08-08T19:00:00+07:00"))
    #expect(draft.endAt == iso8601("2026-08-08T21:00:00+07:00"))
    #expect(draft.locationTo == "<REDACTED>")
    #expect(draft.rateDetails?.totalPriceAmount == 53.94)
    #expect(draft.rateDetails?.totalPriceCurrency == "EUR")
    #expect(draft.rateDetails?.passengerCount == 3)

    #expect(draft.deadlines.count == 1)
    let deadline = try #require(draft.deadlines.first)
    #expect(deadline.deadlineAt == iso8601("2026-08-07T19:00:00+07:00"))
    #expect(deadline.isFreeCancellation == true)
    #expect(deadline.policyText?.contains("vollständige Rückerstattung") == true)
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

@Test("GetYourGuideMyBookingsParser überspringt done-Status")
func gygMyBookingsSkipsDoneStatusAndKeepsOthers() throws {
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
          }
        ]
      }
    }
    """
    let catalog = try GetYourGuideMyBookingsParser.parse(from: json)
    #expect(catalog.bookings.map(\.confirmationCode) == ["keep-ref"])
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
    #expect(enrichment.rateDetails?.passengerCount == 3)

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

@Test("GetYourGuideInitialState extrahiert JSON-Objekt per Brace-Scan")
func gygInitialStateExtractsBalancedJSON() throws {
    let payload = #"{"myBookings":{"upcomingBookings":[]}}"#
    let html = """
    <html><script>window.__INITIAL_STATE__ = \(payload);</script></html>
    """
    let extracted = try #require(GetYourGuideInitialState.extractJSONObject(fromHTML: html))
    #expect(extracted == payload)

    let nested = #"{"a":{"b":"}"},"c":1}"#
    let nestedHTML = "prefix __INITIAL_STATE__ = \(nested) // trailing"
    #expect(GetYourGuideInitialState.extractJSONObject(fromHTML: nestedHTML) == nested)
}

private func iso8601(_ value: String) -> Date {
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withInternetDateTime]
    return fmt.date(from: value)!
}
