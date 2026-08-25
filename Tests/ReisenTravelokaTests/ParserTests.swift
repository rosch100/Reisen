import Foundation
import Testing
import ReisenDomain
import ReisenProviders
@testable import ReisenTraveloka

private enum TravelokaFixtureLoader {
    static func load(_ name: String) throws -> String {
        let candidates = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("docs/fixtures/provider-research/\(name)"),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("docs/fixtures/provider-research/\(name)"),
        ]
        for url in candidates {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
        }
        Issue.record("Fixture missing: \(name)")
        throw TravelokaProviderError.invalidResponse
    }
}

@Test func travelokaCatalogParsesAllProductTypes() throws {
    let text = try TravelokaFixtureLoader.load("traveloka_itineraries_fetch_redacted.json")
    let catalog = try TravelokaCatalogParser.parse(from: text)
    #expect(catalog.bookings.count == 4)

    let byType = Dictionary(uniqueKeysWithValues: catalog.bookings.map { ($0.bookingType, $0) })
    let activity = try #require(byType[.activity])
    #expect(activity.provider == .traveloka)
    #expect(activity.confirmationCode == "1387358428")
    #expect(activity.title?.contains("Ha Noi") == true)
    #expect(activity.operatorName == "AXES")
    #expect(activity.isAllDay == true)
    #expect(activity.status == .confirmed)
    #expect(activity.externalUrl?.contains("type=EXPERIENCE") == true)

    let hotel = try #require(byType[.hotel])
    #expect(hotel.confirmationCode == "1387353870")
    #expect(hotel.title?.contains("Example Hotel") == true)
    #expect(hotel.rateDetails?.boardType == .roomOnly)

    let vehicle = try #require(byType[.other])
    #expect(vehicle.confirmationCode == "1387355867")
    #expect(vehicle.operatorName == "Jayamahe Easy Ride Jakarta")
    #expect(vehicle.locationFrom?.contains("Bandara") == true)

    let flight = try #require(catalog.bookings.first { $0.bookingType == .flight })
    #expect(flight.confirmationCode == "1000000001")
    #expect(flight.title?.contains("Jakarta") == true)
}

@Test func travelokaCatalogUsesSessionRoutePrefixInDetailURL() throws {
    let text = try TravelokaFixtureLoader.load("traveloka_itineraries_fetch_redacted.json")
    let catalog = try TravelokaCatalogParser.parse(from: text, routePrefix: "id-id")
    let activity = try #require(catalog.bookings.first { $0.bookingType == .activity })
    #expect(activity.externalUrl?.contains("/id-id/item/details/1387358428") == true)
}

@Test func travelokaHotelBoardTypeFromBreakfastIncluded() throws {
    let baseEntry: [String: Any] = [
        "bookingId": "999",
        "itineraryId": "888",
        "itineraryType": "HOTEL",
        "cardSummaryInfo": [
            "commonSummary": [
                "itineraryTimestampBegin": 1_700_000_000_000,
                "itineraryTimestampEnd": 1_700_086_400_000,
            ],
            "hotelSummary": [
                "hotelName": "Board Test Hotel",
                "checkInDate": ["day": 1, "month": 1, "year": 2026],
                "checkOutDate": ["day": 2, "month": 1, "year": 2026],
            ],
        ],
        "cardDetailInfo": [
            "hotelDetail": [:],
        ],
    ]

    var missingBreakfast = baseEntry
    let draftUnknown = try TravelokaItineraryEntryParser.draft(from: missingBreakfast)
    #expect(draftUnknown.rateDetails?.boardType == .unknown)
    #expect(draftUnknown.rateDetails?.includedBreakfast == nil)

    var withFalse = baseEntry
    var summaryFalse = (withFalse["cardSummaryInfo"] as! [String: Any])
    var hotelSummaryFalse = (summaryFalse["hotelSummary"] as! [String: Any])
    hotelSummaryFalse["breakfastIncluded"] = false
    summaryFalse["hotelSummary"] = hotelSummaryFalse
    withFalse["cardSummaryInfo"] = summaryFalse
    let draftRoomOnly = try TravelokaItineraryEntryParser.draft(from: withFalse)
    #expect(draftRoomOnly.rateDetails?.boardType == .roomOnly)
    #expect(draftRoomOnly.rateDetails?.includedBreakfast == false)

    var withTrue = baseEntry
    var summaryTrue = (withTrue["cardSummaryInfo"] as! [String: Any])
    var hotelSummaryTrue = (summaryTrue["hotelSummary"] as! [String: Any])
    hotelSummaryTrue["breakfastIncluded"] = true
    summaryTrue["hotelSummary"] = hotelSummaryTrue
    withTrue["cardSummaryInfo"] = summaryTrue
    let draftBreakfast = try TravelokaItineraryEntryParser.draft(from: withTrue)
    #expect(draftBreakfast.rateDetails?.boardType == .breakfastIncluded)
    #expect(draftBreakfast.rateDetails?.includedBreakfast == true)
}

@Test func travelokaEnrichmentExperience() throws {
    let text = try TravelokaFixtureLoader.load("traveloka_itinerary_single_experience_redacted.json")
    let enrichment = try TravelokaEnrichmentParser.parse(from: text)
    #expect(enrichment.title?.contains("Ha Noi") == true)
    #expect(enrichment.operatorName == "AXES")
    #expect(enrichment.isAllDay == true)
    #expect(enrichment.status == .confirmed)
    #expect(enrichment.locationTo?.contains("Hoan Kiem") == true)
    #expect(enrichment.passengers?.count == 1)
    #expect(enrichment.passengers?.first?.travellerType == .child)
    #expect(enrichment.deadlines.count == 1)
    #expect(enrichment.deadlines.first?.isFreeCancellation == true)
}

@Test func travelokaEnrichmentHotelDualDeadlines() throws {
    let text = try TravelokaFixtureLoader.load("traveloka_itinerary_single_hotel_redacted.json")
    let enrichment = try TravelokaEnrichmentParser.parse(from: text)
    #expect(enrichment.title?.contains("Example Hotel") == true)
    #expect(enrichment.hotelCheckInMinutes == 14 * 60)
    #expect(enrichment.hotelCheckOutMinutes == 12 * 60)
    #expect(enrichment.deadlines.count == 2)
    #expect(enrichment.deadlines.contains { $0.isFreeCancellation })
    #expect(enrichment.deadlines.contains { !$0.isFreeCancellation && $0.cancellationFeeAmount == 4.37 })
    #expect(enrichment.rateDetails?.includedBreakfast == false)
}

@Test func travelokaEnrichmentVehicle() throws {
    let text = try TravelokaFixtureLoader.load("traveloka_itinerary_single_vehicle_redacted.json")
    let enrichment = try TravelokaEnrichmentParser.parse(from: text)
    #expect(enrichment.title == "Daihatsu Sigra")
    #expect(enrichment.operatorName == "Jayamahe Easy Ride Jakarta")
    #expect(enrichment.locationFrom?.contains("Bandara") == true)
    #expect(enrichment.locationFromAddress?.contains("Jakarta") == true)
    #expect(enrichment.deadlines.count == 1)
    #expect(enrichment.deadlines.first?.isFreeCancellation == true)
}

@Test func travelokaEnrichmentFlightNonRefundable() throws {
    let text = try TravelokaFixtureLoader.load("traveloka_itinerary_single_flight_redacted.json")
    let enrichment = try TravelokaEnrichmentParser.parse(from: text)
    #expect(enrichment.title?.contains("Jakarta") == true)
    #expect(enrichment.rateDetails?.airline == "AirAsia")
    #expect(enrichment.deadlines.isEmpty)
    #expect(enrichment.flightDepartureOffsetSeconds != nil)
    #expect(enrichment.passengers?.count == 1)
    #expect(enrichment.passengers?.first?.travellerType == .adult)
    #expect(enrichment.locationFrom?.contains("CGK") == true)
}

@Test func travelokaEnrichmentFlightFeeRefund() throws {
    let text = try TravelokaFixtureLoader.load("traveloka_itinerary_single_flight_fee_redacted.json")
    let enrichment = try TravelokaEnrichmentParser.parse(from: text)
    #expect(enrichment.deadlines.count == 1)
    let deadline = try #require(enrichment.deadlines.first)
    #expect(deadline.isFreeCancellation == false)
    #expect(deadline.cancellationFeeAmount == 25.0)
    #expect(enrichment.passengers?.count == 2)
    #expect(enrichment.passengers?.contains { $0.travellerType == .child } == true)
    #expect(enrichment.rateDetails?.passengerCount == 2)
}

@Test func travelokaWhoAmIProbeTV() throws {
    let text = try TravelokaFixtureLoader.load("traveloka_whoami_redacted.json")
    #expect(TravelokaSessionProbeJSON.isLoggedIn(fromWhoAmIJSON: text) == true)
}

@Test func travelokaWhoAmIProbeAP() throws {
    let text = try TravelokaFixtureLoader.load("traveloka_whoami_apple_redacted.json")
    #expect(TravelokaSessionProbeJSON.isLoggedIn(fromWhoAmIJSON: text) == true)
}

@Test func travelokaWhoAmIProbeAnonymousWithoutLoginMethod() throws {
    let text = try TravelokaFixtureLoader.load("traveloka_whoami_anonymous_redacted.json")
    #expect(TravelokaSessionProbeJSON.isLoggedIn(fromWhoAmIJSON: text) == false)
}

@Test func travelokaDetailURLIds() throws {
    let url = "https://www.traveloka.com/en-en/item/details/1387358428?type=EXPERIENCE&id=1874509835987345547"
    let ids = try TravelokaExternalURL.detailIds(from: url)
    #expect(ids.bookingId == "1387358428")
    #expect(ids.itineraryId == "1874509835987345547")
    #expect(ids.productType == "EXPERIENCE")
}

@Test func travelokaEnrichmentCancelledStatus() throws {
    let text = try TravelokaFixtureLoader.load("traveloka_itinerary_single_cancelled_redacted.json")
    let enrichment = try TravelokaEnrichmentParser.parse(from: text)
    #expect(enrichment.status == .cancelled)
    #expect(enrichment.title?.contains("Cancelled Sample") == true)
}

@Test func travelokaRefundPresubmissionParsesFreeDeadline() throws {
    let html = try TravelokaFixtureLoader.load("traveloka_refund_presubmission_experience_redacted.html")
    let tz = try #require(TimeZone(identifier: "Asia/Saigon"))
    let deadlines = try TravelokaRefundPresubmissionParser.deadlines(fromHTML: html, timeZone: tz)
    #expect(deadlines.count == 2)

    let free = try #require(deadlines.first { $0.isFreeCancellation })
    #expect(free.cancellationFeeAmount == nil)

    let fee = try #require(deadlines.first { !$0.isFreeCancellation })
    #expect(fee.cancellationFeeAmount == 7.5)

    // Reschedule + fremde feeAmount im unrelated-Objekt dürfen nicht greifen.
    #expect(!deadlines.contains { $0.cancellationFeeAmount == 99.0 })
}

@Test func travelokaStatusMapperIgnoresRefundableTag() {
    let refundableEntry: [String: Any] = [
        "itineraryTags": [
            ["text": "Refundable", "status": "STATUS_OK"],
            ["text": "Voucher issued", "status": "STATUS_OK"],
        ],
        "paymentInfo": ["userTripStatus": "ETICKET_PUBLISHED"],
    ]
    #expect(TravelokaStatusMapper.status(from: refundableEntry) == .confirmed)
    #expect(TravelokaStatusMapper.isCancelledStatusTag("Refundable") == false)
    #expect(TravelokaStatusMapper.isCancelledStatusTag("Non-cancellable") == false)
    #expect(TravelokaStatusMapper.isCancelledStatusTag("Booking cancelled") == true)
    #expect(TravelokaStatusMapper.isCancelledTripStatus("REFUNDED") == true)
    #expect(TravelokaStatusMapper.isCancelledTripStatus("CANCELLED") == true)
    #expect(TravelokaStatusMapper.isCancelledTripStatus("ETICKET_PUBLISHED") == false)
    #expect(TravelokaStatusMapper.isCancelledTripStatus("CANCELLATION_AVAILABLE") == false)
}

@Test func travelokaEnrichmentTimeZoneIdentifierFromFixture() throws {
    let text = try TravelokaFixtureLoader.load("traveloka_itinerary_single_experience_redacted.json")
    #expect(TravelokaEnrichmentParser.timeZoneIdentifier(from: text) == "Asia/Saigon")
}

@Test func travelokaSessionContextFromCookiesMapsSentinelAndClientSession() {
    let sen = HTTPCookie(properties: [
        .name: "sen_t",
        .value: "sentinel-token-example",
        .domain: ".traveloka.com",
        .path: "/",
    ])!
    let client = HTTPCookie(properties: [
        .name: "clientSessionId",
        .value: "T1-web.01M0WQ8DDMGGBJPA91D8HQXHRW",
        .domain: ".traveloka.com",
        .path: "/",
    ])!
    var context = TravelokaSessionContext.from(cookies: [sen, client])
    context.mergingDeviceIdFromStorageScan("01M0WN1JV47ME3VXW94W9CCN1S")

    #expect(context.sentinelToken == "sentinel-token-example")
    #expect(context.clientSessionId == "T1-web.01M0WQ8DDMGGBJPA91D8HQXHRW")
    #expect(context.deviceId == "01M0WN1JV47ME3VXW94W9CCN1S")
    #expect(context.xDidHeaderValue == "MDFNMFdOMUpWNDdNRTNWWFc5NFc5Q0NOMVM=")

    let headers = context.applying(to: ["x-domain": "tripItinerary"])
    #expect(headers["tv-clientsessionid"] == "T1-web.01M0WQ8DDMGGBJPA91D8HQXHRW")
    #expect(headers["x-did"] == "MDFNMFdOMUpWNDdNRTNWWFc5NFc5Q0NOMVM=")

    let body = context.withSentinel(in: ["clientInterface": "desktop"])
    let sentinel = body["sentinel"] as? [String: Any]
    #expect(sentinel?["token"] as? String == "sentinel-token-example")
}

@Test func travelokaEnrichmentNeedsSkipsCompleteCatalogDraft() {
    let complete = ProviderBookingDraft(
        provider: .traveloka,
        bookingType: .hotel,
        startAt: Date(),
        endAt: Date(),
        status: .confirmed,
        deadlines: [
            CancellationDeadline(
                deadlineAt: Date(),
                policyText: "Free",
                isFreeCancellation: true
            ),
        ],
        hotelCheckInMinutes: 14 * 60,
        hotelCheckOutMinutes: 12 * 60
    )
    #expect(TravelokaEnrichmentNeeds.shouldEnrich(complete, requiresDeadlines: true) == false)

    let missingCheckIn = ProviderBookingDraft(
        provider: .traveloka,
        bookingType: .hotel,
        startAt: Date(),
        endAt: Date(),
        status: .confirmed,
        deadlines: complete.deadlines,
        hotelCheckOutMinutes: 12 * 60
    )
    #expect(TravelokaEnrichmentNeeds.shouldEnrich(missingCheckIn, requiresDeadlines: true) == true)
}

@Test func travelokaSessionContextResolvesLocaleFromURLAndCookies() {
    let currency = HTTPCookie(properties: [
        .name: "tv_currency",
        .value: "IDR",
        .domain: ".traveloka.com",
        .path: "/",
    ])!
    var context = TravelokaSessionContext.from(cookies: [currency])
    context.applyPageContext(from: URL(string: "https://www.traveloka.com/id-id/user/mybooking")!)

    #expect(context.resolvedRoutePrefix == "id-id")
    #expect(context.resolvedLanguage == "id_ID")
    #expect(context.resolvedCountry == "ID")
    #expect(context.resolvedCurrency == "IDR")

    let headers = context.applying(to: [:])
    #expect(headers["tv-language"] == "id_ID")
    #expect(headers["tv-country"] == "ID")
    #expect(headers["tv-currency"] == "IDR")
    #expect(headers["x-route-prefix"] == "id-id")
}

@Test func travelokaRefundPresubmissionDedupesDuplicateDeadlineKeys() throws {
    let html = """
    <html><body>
    <script id="__NEXT_DATA__" type="application/json">{
      "props": {
        "pageProps": {
          "a": { "freeCancellationDeadlineLocal": "2026-09-06T23:59:00" },
          "b": { "freeCancellationDeadlineLocal": "2026-09-06T23:59:00" }
        }
      }
    }</script>
    </body></html>
    """
    let tz = try #require(TimeZone(identifier: "Asia/Saigon"))
    let deadlines = try TravelokaRefundPresubmissionParser.deadlines(fromHTML: html, timeZone: tz)
    #expect(deadlines.count == 1)
}
