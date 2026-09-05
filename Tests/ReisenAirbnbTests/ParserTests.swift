import Testing
import Foundation
import ReisenDomain
@testable import ReisenAirbnb

@Test("AirbnbTravelProvider erkennt internationale Airbnb-Hosts")
func airbnbHostMatchingIncludesInternationalTLDs() {
    #expect(AirbnbTravelProvider.isAirbnbHost("www.airbnb.co.uk"))
    #expect(AirbnbTravelProvider.isAirbnbHost("airbnb.fr"))
    #expect(AirbnbTravelProvider.isAirbnbHost("www.airbnb.de"))
    #expect(!AirbnbTravelProvider.isAirbnbHost("evil-airbnb.com"))
    #expect(!AirbnbTravelProvider.isAirbnbHost("phishing.com"))
}

@Test("AirbnbListingTimeZone: ungültige IANA → nil Offset")
func airbnbInvalidListingTimeZoneYieldsNilOffset() {
    let date = Date(timeIntervalSince1970: 1_780_000_000)
    #expect(AirbnbListingTimeZone.offsetSeconds(listingTimeZone: "Not/A_Real_Zone", at: date) == nil)
    #expect(AirbnbListingTimeZone.offsetSeconds(listingTimeZone: "Europe/Berlin", at: date) != nil)
}

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
    #expect(deadline.policyText?.localizedCaseInsensitiveContains("non-refundable") == true)
}

@Test("AirbnbScheduledEventsPayment parst EN Total-cost mit Dezimalpunkt (Sync-Locale)")
func airbnbScheduledEventsPaymentParsesEnglishTotalCost() {
    let rows = [
        AirbnbScheduledEventRow(
            id: "payment_summary",
            leadingSubtitle: nil,
            trailingSubtitle: nil,
            subtitle: "Total cost: €133.15",
            cancellationMilestoneModalV2: nil
        )
    ]
    let rate = AirbnbScheduledEventsPayment.parse(rows: rows)
    #expect(rate?.totalPriceAmount == 133.15)
    #expect(rate?.totalPriceCurrency == "EUR")
}

@Test("AirbnbMoneyAmount parst EN- und DE-Tausender korrekt")
func airbnbMoneyAmountParsesGroupedThousands() {
    #expect(AirbnbMoneyAmount.parse(from: "Total cost: €1,234.56") == 1234.56)
    #expect(AirbnbMoneyAmount.parse(from: "Gesamtkosten: 1.234,56 €") == 1234.56)
    #expect(AirbnbMoneyAmount.parse(from: "52,56 €") == 52.56)
}

@Test("AirbnbScheduledEventsCancellation nutzt end_at als Free-Cancel-Frist")
func airbnbScheduledEventsCancellationUsesEndAtForFreeRefund() {
    let freeUntil = iso8601("2026-09-30T12:00:00.000Z")
    let entry = AirbnbScheduledEventRow.CancellationMilestoneEntry(
        timelineTitle: "Before",
        refundType: "Full refund",
        refundTerm: "Get back 100% of what you paid.",
        startAt: iso8601("2026-08-30T15:41:33.336Z"),
        endAt: freeUntil
    )
    let deadline = AirbnbScheduledEventsCancellation.deadline(from: entry)
    #expect(deadline?.isFreeCancellation == true)
    #expect(deadline.map { abs($0.deadlineAt.timeIntervalSince(freeUntil)) < 0.01 } == true)
}

@Test("AirbnbScheduledEventsCancellation verwirft Free-Tier ohne end_at")
func airbnbScheduledEventsCancellationDropsFreeWithoutEndAt() {
    let entry = AirbnbScheduledEventRow.CancellationMilestoneEntry(
        timelineTitle: "Before",
        refundType: "Full refund",
        refundTerm: "Get back 100% of what you paid.",
        startAt: iso8601("2026-08-30T15:41:33.336Z"),
        endAt: nil
    )
    #expect(AirbnbScheduledEventsCancellation.deadline(from: entry) == nil)
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

@Test("AirbnbStayEnrichment schreibt Adresse, Gäste und Zimmer aus TripDetails")
func airbnbStayEnrichmentWritesAddressGuestsAndRooms() throws {
    let json = try fixtureJSON("trip_details_sample.json")
    let confirmationCode = "HMSN84QMWF"
    let details = try AirbnbTripDetailsParser.parse(
        responseText: json,
        bookingType: .hotel,
        confirmationCode: confirmationCode
    )
    let scheduled = AirbnbScheduledEventsParseResult(
        deadlines: [],
        rateDetails: BookingRateDetails(totalPriceAmount: 120, totalPriceCurrency: "EUR"),
        hotelCheckInMinutes: 15 * 60,
        hotelCheckOutMinutes: 10 * 60
    )
    let enrichment = DraftAssembler.enrichment(
        from: AirbnbStayEnrichment.facts(
            bookingType: .hotel,
            tripDetails: details,
            scheduled: scheduled,
            hotelOffsetSeconds: 3600,
            guestHints: []
        )
    )
    #expect(enrichment.locationToAddress == details.oneLineAddress)
    #expect(enrichment.rateDetails?.guestCount == 1)
    #expect(enrichment.rateDetails?.roomCount == 1)
    #expect(enrichment.rateDetails?.totalPriceAmount == 120)
    #expect(enrichment.hotelCheckInMinutes == 15 * 60)
}

@Test func airbnbExperienceCancellationURLEncodesPathSegment() {
    #expect(
        AirbnbAPI.experienceCancellationURL(confirmationCode: "TAJ8FMXK")
            == "https://www.airbnb.de/experience_alteration/TAJ8FMXK?flow=oneCancel&productType=experience"
    )
    #expect(
        AirbnbAPI.experienceCancellationURL(confirmationCode: "a/b")
            == "https://www.airbnb.de/experience_alteration/a%2Fb?flow=oneCancel&productType=experience"
    )
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
    #expect(draft.title == nil)
    #expect(draft.locationTo == "Gedong Tengen")
    #expect(draft.passengers.isEmpty)
    #expect(draft.rateDetails?.guestCount == 3)
    #expect(draft.startAt == iso8601("2026-08-10T11:00:00.000Z"))
    #expect(draft.endAt == iso8601("2026-08-10T14:00:00.000Z"))
    #expect(draft.externalUrl?.contains("EXPERIENCE_RESERVATION") == true)
    #expect(
        draft.cancellationUrl
            == "https://www.airbnb.de/experience_alteration/%3CREDACTED%3E?flow=oneCancel&productType=experience"
    )
    #expect(draft.cancellationUrl != draft.externalUrl)
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

@Test("AirbnbActivityReservationDetailsParser ignoriert nicht-EN Cancel-Policy-Text")
func airbnbActivityReservationDetailsIgnoresNonEnglishCancelPolicy() throws {
    let json = """
    {
      "scheduled_event": {
        "rows": [
          {
            "id": "cancel_policy",
            "payload": {
              "subtitle": "Storniere bis 9. Aug., 18:00 Uhr (WIB) für eine vollständige Rückerstattung."
            }
          }
        ]
      }
    }
    """
    let reference = iso8601("2026-08-10T11:00:00.000Z")
    let result = try AirbnbActivityReservationDetailsParser.parse(
        responseText: json,
        referenceDate: reference
    )
    #expect(result.deadlines.isEmpty)
}

private func fixtureJSON(_ name: String) throws -> String {
    try TestFixtures.text(name)
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

@Test("AirbnbScheduledEventsCancellation klassifiziert Free/Non-Refund ohne Substring-Falschtreffer")
func airbnbScheduledEventsCancellationClassifiesPrecisely() {
    let ambiguous = AirbnbScheduledEventRow.CancellationMilestoneEntry(
        timelineTitle: nil,
        refundType: "partially refundable",
        refundTerm: "Includes full terms in footer",
        startAt: Date(),
        endAt: nil
    )
    #expect(AirbnbScheduledEventsCancellation.classifyFreeCancellation(ambiguous) == nil)

    let fullRefund = AirbnbScheduledEventRow.CancellationMilestoneEntry(
        timelineTitle: nil,
        refundType: "Full refund",
        refundTerm: nil,
        startAt: Date(),
        endAt: nil
    )
    #expect(AirbnbScheduledEventsCancellation.classifyFreeCancellation(fullRefund) == true)

    let freeToken = AirbnbScheduledEventRow.CancellationMilestoneEntry(
        timelineTitle: nil,
        refundType: "free",
        refundTerm: nil,
        startAt: Date(),
        endAt: nil
    )
    #expect(AirbnbScheduledEventsCancellation.classifyFreeCancellation(freeToken) == true)

    let germanFull = AirbnbScheduledEventRow.CancellationMilestoneEntry(
        timelineTitle: nil,
        refundType: "Vollständige Rückerstattung",
        refundTerm: nil,
        startAt: Date(),
        endAt: nil
    )
    #expect(AirbnbScheduledEventsCancellation.classifyFreeCancellation(germanFull) == true)

    let germanNone = AirbnbScheduledEventRow.CancellationMilestoneEntry(
        timelineTitle: nil,
        refundType: "Keine Rückerstattung",
        refundTerm: nil,
        startAt: Date(),
        endAt: nil
    )
    #expect(AirbnbScheduledEventsCancellation.classifyFreeCancellation(germanNone) == false)

    let partialWithNightClause = AirbnbScheduledEventRow.CancellationMilestoneEntry(
        timelineTitle: nil,
        refundType: "Anteilige Rückerstattung",
        refundTerm: "Keine Rückerstattung der Kosten für die erste Nacht oder der Servicegebühr.",
        startAt: Date(),
        endAt: nil
    )
    #expect(AirbnbScheduledEventsCancellation.classifyFreeCancellation(partialWithNightClause) == nil)
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

@Test("AirbnbTripsGraphQLParser behält Draft ohne Portal-URL")
func airbnbTripListKeepsDraftWithoutPortalURL() throws {
    // id ist kein gültiges Relay "Trip:<n>" → keine Portal-URL, Draft bleibt (Open-UI ausgeblendet).
    let json = """
    {
      "data": {
        "viewer": {
          "trips": {
            "edges": [
              {
                "node": {
                  "id": "not-a-relay-trip-id",
                  "displayName": "Testort",
                  "status": "UPCOMING",
                  "startTime": { "listingTimeZone": "UTC", "dateTime": "2099-08-01T12:00:00.000Z" },
                  "endTime": { "listingTimeZone": "UTC", "dateTime": "2099-08-02T12:00:00.000Z" },
                  "scheduledItems": {
                    "edges": [
                      {
                        "node": {
                          "details": {
                            "schedulableType": "RESERVATION",
                            "stayReservation": {
                              "confirmationCode": "ABC123",
                              "status": "ACCEPT"
                            }
                          }
                        }
                      }
                    ]
                  }
                }
              }
            ]
          }
        }
      }
    }
    """
    let catalog = try AirbnbTripsGraphQLParser.parseTripList(from: json)
    let draft = try #require(catalog.bookings.first)
    #expect(draft.confirmationCode == "ABC123")
    #expect(draft.externalUrl == nil)
    #expect(draft.cancellationUrl == nil)
}
