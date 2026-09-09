import Foundation
import Testing
import ReisenDomain
@testable import ReisenExpedia

private enum ExpediaFixtureLoader {
    private static let fixturesRelativePath = "docs/fixtures/provider-research"

    static func load(_ name: String) throws -> String {
        let fromCWD = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(fixturesRelativePath)
            .appendingPathComponent(name)
        let fromSource = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(fixturesRelativePath)
            .appendingPathComponent(name)
        for url in [fromCWD, fromSource] {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
        }
        Issue.record("Fixture missing: \(name)")
        throw ExpediaProviderError.invalidResponse
    }

    static func loadJSON(_ name: String) throws -> [String: Any] {
        let text = try load(name)
        guard let data = text.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw ExpediaProviderError.invalidResponse
        }
        return json
    }
}

@Test func expediaTripsListParsesTripViewIDs() throws {
    let html = try ExpediaFixtureLoader.load("expedia_trips_list_redacted.html")
    let ids = ExpediaTripsListParser.tripViewIDs(fromHTML: html)
    #expect(ids == ["egti-AAA-111-TEST", "egti-BBB-222-TEST"])
}

@Test func expediaCatalogParsesHotelCard() async throws {
    let data = try ExpediaFixtureLoader.loadJSON("expedia_trip_items_hotel_redacted.json")
    let drafts = await ExpediaCatalogParser.drafts(fromTripItemsData: data, tripViewId: "egti-TEST-VIEW-0001")
    let hotel = try #require(drafts.first { $0.bookingType == .hotel })
    #expect(hotel.provider == .expedia)
    #expect(hotel.title?.contains("martas") == true)
    #expect(hotel.status == .confirmed)
    #expect(hotel.confirmationCode == nil)
    #expect(hotel.externalUrl?.contains("/trips/egti-TEST-VIEW-0001/details/") == true)
    #expect(hotel.cancellationUrl == nil)
    #expect(hotel.endAt > hotel.startAt)
    #expect(hotel.hotelCheckInMinutes == 15 * 60)
    #expect(hotel.hotelCheckOutMinutes == 10 * 60)
}

@Test func expediaCatalogParsesCarCard() async throws {
    let data = try ExpediaFixtureLoader.loadJSON("expedia_trip_items_car_redacted.json")
    let drafts = await ExpediaCatalogParser.drafts(fromTripItemsData: data, tripViewId: "egti-TEST-VIEW-0001")
    let car = try #require(drafts.first { $0.bookingType == .carRental })
    #expect(car.operatorName == "Dollar")
    #expect(car.cancellationUrl?.contains("/manage-booking") == true)
    #expect(car.confirmationCode == nil)
}

@Test func expediaCatalogParsesSyntheticFlightAndActivity() async throws {
    let flightData = try ExpediaFixtureLoader.loadJSON("expedia_trip_items_flight_synthetic.json")
    let flightDrafts = await ExpediaCatalogParser.drafts(
        fromTripItemsData: flightData,
        tripViewId: "egti-TEST-VIEW-0001"
    )
    let flight = try #require(flightDrafts.first)
    #expect(flight.bookingType == .flight)
    #expect(flight.title == "FRA → BER")
    #expect(flight.cancellationUrl == nil)

    let activityData = try ExpediaFixtureLoader.loadJSON("expedia_trip_items_activity_synthetic.json")
    let activityDrafts = await ExpediaCatalogParser.drafts(
        fromTripItemsData: activityData,
        tripViewId: "egti-TEST-VIEW-0001"
    )
    let activity = try #require(activityDrafts.first)
    #expect(activity.bookingType == .activity)
    #expect(activity.title == "City Walking Tour")
    #expect(activity.cancellationUrl == nil)
}

@Test func expediaCatalogSkipsUnknownProductPrefix() async throws {
    let data: [String: Any] = [
        "tripItems": [
            "itemGroups": [
                [
                    "sections": [
                        [
                            "cards": [
                                [
                                    "__typename": "TripsUIBookedItemCard",
                                    "identifier": "eg:unknown:v2:abc",
                                    "primary": "Mystery",
                                    "badge": ["text": "Gebucht"],
                                    "enrichedSecondaries": [
                                        ["text": "von 1. Dez., 10:00 Uhr bis 2. Dez., 10:00 Uhr"],
                                    ],
                                    "cardAction": [
                                        "resource": [
                                            "value": "https://www.expedia.de/trips/egti-TEST-VIEW-0001/details/abc",
                                        ],
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
        ],
    ]
    let drafts = await ExpediaCatalogParser.drafts(fromTripItemsData: data, tripViewId: "egti-TEST-VIEW-0001")
    #expect(drafts.isEmpty)
}

@Test func expediaHotelCancellationURLFromServicing() throws {
    let data = try ExpediaFixtureLoader.loadJSON("expedia_booking_servicing_hotel_redacted.json")
    let url = ExpediaEnrichmentParser.hotelCancellationURL(fromServicingData: data)
    #expect(url?.contains("/booking-servicing/lodging/voluntary/cancel/review") == true)
}

@Test func expediaHotelDeadlinesFromServicing() throws {
    let data = try ExpediaFixtureLoader.loadJSON("expedia_booking_servicing_hotel_redacted.json")
    let deadlines = ExpediaEnrichmentParser.cancellationDeadlines(fromServicingData: data)
    // Fixture policy uses “Ortszeit der Unterkunft” → no invented Berlin absolute deadline.
    #expect(deadlines.isEmpty)
}

@Test func expediaHotelDeadlineParsesNonPropertyLocalWallClock() {
    let texts = [
        "Du kannst bis zum 6. Dez. 2026, 18:00 Uhr kostenlos stornieren.",
    ]
    let deadlines = ExpediaEnrichmentParser.parseFreeCancellationDeadlines(from: texts)
    #expect(deadlines.count == 1)
    #expect(deadlines.first?.isFreeCancellation == true)
    #expect(deadlines.first?.hotelOffsetSeconds != nil)
}

@Test func expediaRoomCategoryFromRoomDetails() throws {
    let data = try ExpediaFixtureLoader.loadJSON("expedia_room_details_hotel_redacted.json")
    let category = ExpediaEnrichmentParser.roomCategory(fromRoomDetails: data)
    #expect(category?.contains("Schlafsaal") == true)
}

@Test func expediaLodgingServicingTripIdFromEncodedTripItem() {
    let encoded =
        "MDAwMDAwMDAtMDAwMC00MDAwLTgwMDAtMDAwMDAwMDAwMTAxOzAwMDAwMDAwLTAwMDAtNDAwMC04MDAwLTAwMDAwMDAwMDEwMl8wO2VnOnByb3BlcnR5OnYyOnRlc3Rob3RlbHByb2R1Y3RpZDAwMDE="
    #expect(
        ExpediaExternalURL.lodgingServicingTripId(fromEncodedTripItemId: encoded)
            == "00000000-0000-4000-8000-000000000101"
    )
}

@Test func expediaCarEnrichmentParsesConfirmationAndVendor() throws {
    let data = try ExpediaFixtureLoader.loadJSON("expedia_trip_item_car_redacted.json")
    let enrichment = ExpediaEnrichmentParser.enrichment(
        fromTripItemData: data,
        bookingType: .carRental,
        externalUrl: "https://www.expedia.de/trips/egti-TEST-VIEW-0001/details/x",
        cancellationUrl: "https://www.expedia.de/trips/egti-TEST-VIEW-0001/details/x/manage-booking"
    )
    #expect(enrichment.operatorName == "Dollar")
    #expect(enrichment.confirmationCode == "L70REDACTED01")
    #expect(enrichment.cancellationUrl?.contains("/manage-booking") == true)
}

@Test func expediaHotelEnrichmentParsesConfirmationPriceAndCancelFromTripItem() throws {
    let data = try ExpediaFixtureLoader.loadJSON("expedia_trip_item_hotel_redacted.json")
    let enrichment = ExpediaEnrichmentParser.enrichment(
        fromTripItemData: data,
        bookingType: .hotel,
        externalUrl: "https://www.expedia.de/trips/egti-TEST-VIEW-0001/details/hotel-item",
        cancellationUrl: nil
    )
    #expect(enrichment.title?.contains("martas") == true)
    #expect(enrichment.confirmationCode == "H70REDACTED01")
    #expect(enrichment.rateDetails?.totalPriceAmount == 89)
    #expect(enrichment.cancellationUrl?.contains("/booking-servicing/") == true)
}

@Test func expediaHotelSidePathRoomDetailsPolicy() {
    #expect(
        ExpediaHotelSidePath.roomDetailsHandling(for: CancellationError()) == .hardFail
    )
    #expect(
        ExpediaHotelSidePath.roomDetailsHandling(for: ExpediaProviderError.graphqlErrors) == .hardFail
    )
    #expect(
        ExpediaHotelSidePath.roomDetailsHandling(for: ExpediaProviderError.graphqlHashRejected)
            == .hardFail
    )
    #expect(
        ExpediaHotelSidePath.roomDetailsHandling(for: ExpediaProviderError.invalidResponse)
            == .softContinue
    )
}

@Test func expediaDeepLinkBuilderHotelAndTimedCar() {
    let builder = ExpediaDeepLinkBuilder()
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    let start = cal.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 10, minute: 30))!
    let end = cal.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 10, minute: 30))!
    let gap = GapContext(
        gapStart: start,
        gapEnd: end,
        kind: .both,
        fromLocationFrom: nil,
        fromLocationTo: "Berlin",
        toLocationFrom: nil,
        toLocationTo: nil
    )
    let result = builder.suggestions(for: gap)
    #expect(result.links.contains { $0.category == .hotel && $0.url?.host?.contains("expedia.de") == true })
    #expect(result.links.contains { $0.category == .carRental })
    #expect(!result.links.contains { $0.category == .flight })
}

@Test func expediaDeepLinkBuilderOmitsCarWithoutConcreteTimes() {
    let builder = ExpediaDeepLinkBuilder()
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    let start = cal.date(from: DateComponents(year: 2026, month: 10, day: 14))!
    let end = cal.date(from: DateComponents(year: 2026, month: 10, day: 15))!
    let gap = GapContext(
        gapStart: start,
        gapEnd: end,
        kind: .transport,
        fromLocationFrom: nil,
        fromLocationTo: "Berlin",
        toLocationFrom: nil,
        toLocationTo: nil
    )
    let result = builder.suggestions(for: gap)
    #expect(!result.links.contains { $0.category == .carRental })
}

@Test func expediaDraftEnrichmentNeedsOnlyWhenConfirmationMissing() {
    var draft = ProviderBookingDraft(
        provider: .expedia,
        bookingType: .hotel,
        confirmationCode: "ABC",
        cancellationUrl: "https://www.expedia.de/booking-servicing/lodging/voluntary/cancel/review",
        startAt: Date(timeIntervalSince1970: 1),
        endAt: Date(timeIntervalSince1970: 2),
        rateDetails: BookingRateDetails(totalPriceAmount: 10, totalPriceCurrency: "EUR")
    )
    #expect(ExpediaDraftEnrichmentNeeds.shouldEnrich(draft, requiresDeadlines: true) == false)
    draft.cancellationUrl = nil
    draft.rateDetails = nil
    #expect(ExpediaDraftEnrichmentNeeds.shouldEnrich(draft, requiresDeadlines: true) == false)
    draft.confirmationCode = nil
    #expect(ExpediaDraftEnrichmentNeeds.shouldEnrich(draft, requiresDeadlines: false) == true)
}

@Test func expediaScheduleParsesCrossYearHotelStay() {
    let texts = ["von 30. Dez., 15:00 Uhr bis 2. Jan., 10:00 Uhr"]
    let window = ExpediaScheduleParser.window(fromSecondaryTexts: texts, bookingType: .hotel)
    #expect(window != nil)
    guard case let .hotelDay(start, _)? = window?.start,
          case let .hotelDay(end, _)? = window?.end
    else {
        Issue.record("expected hotelDay facts")
        return
    }
    #expect(end > start)
    #expect(window?.hotelCheckInMinutes == 15 * 60)
    #expect(window?.hotelCheckOutMinutes == 10 * 60)
}

@Test func expediaParseEuroAmountHandlesLabelAndThousands() {
    #expect(ExpediaJSON.parseEuroAmount("Gesamtpreis: 1.234,56 €")?.0 == Decimal(string: "1234.56"))
    #expect(ExpediaJSON.parseEuroAmount("1.234 €")?.0 == Decimal(string: "1234"))
    #expect(ExpediaJSON.parseEuroAmount("Room 12 costs 89,00 €")?.0 == Decimal(string: "89.00"))
    #expect(ExpediaJSON.parseEuroAmount("Version 2 without currency") == nil)
}

@Test func expediaGraphQLRejectsErrorsEvenWhenDataPresent() throws {
    let payload = """
    {"data":{"trip":{}},"errors":[{"message":"field boom"}]}
    """
    #expect(throws: ExpediaProviderError.graphqlErrors) {
        try ExpediaGraphQL.decodeDataObject(from: payload)
    }
}

@Test func expediaGraphQLClassifiesPersistedQueryNotFound() throws {
    let payload = """
    {"errors":[{"message":"PersistedQueryNotFound"}]}
    """
    #expect(throws: ExpediaProviderError.graphqlHashRejected) {
        try ExpediaGraphQL.decodeDataObject(from: payload)
    }
}

@Test func expediaProductTypeMapping() {
    #expect(ExpediaProductType.bookingType(fromProductIdentifier: "eg:property:v2:x") == .hotel)
    #expect(ExpediaProductType.bookingType(fromProductIdentifier: "eg:car:v2:x") == .carRental)
    #expect(ExpediaProductType.bookingType(fromProductIdentifier: "eg:flight:v2:x") == .flight)
    #expect(ExpediaProductType.bookingType(fromProductIdentifier: "eg:activity:v2:x") == .activity)
    #expect(ExpediaProductType.bookingType(fromProductIdentifier: "eg:other:v2:x") == nil)
    #expect(ExpediaProductType.bookingType(fromProductIdentifier: "eg:experience:v2:x") == nil)
}

@Test func expediaExternalURLPartsAndManage() {
    let url =
        "https://www.expedia.de/trips/egti-TEST-VIEW-0001/details/dGVzdFRyaXBJdGVtSWQwMDAx"
    let parts = ExpediaExternalURL.parts(from: url)
    #expect(parts?.tripViewId == "egti-TEST-VIEW-0001")
    #expect(parts?.tripItemId == "dGVzdFRyaXBJdGVtSWQwMDAx")
    #expect(
        ExpediaExternalURL.manageBookingURL(
            tripViewId: "egti-TEST-VIEW-0001",
            tripItemId: "dGVzdFRyaXBJdGVtSWQwMDAx"
        ).hasSuffix("/manage-booking")
    )
    let withQuery =
        "https://www.expedia.de/trips/egti-TEST-VIEW-0001/details/abc?utm=x#section"
    #expect(
        ExpediaExternalURL.appendingManageBooking(to: withQuery)
            == "https://www.expedia.de/trips/egti-TEST-VIEW-0001/details/abc/manage-booking?utm=x#section"
    )
    #expect(
        ExpediaExternalURL.appendingManageBooking(
            to: "https://www.expedia.de/trips/egti-x/details/abc/manage-booking?q=1"
        ) == "https://www.expedia.de/trips/egti-x/details/abc/manage-booking?q=1"
    )
}

@Test func expediaHotelServicingSoftPathsVisibleInParsers() {
    #expect(ExpediaExternalURL.lodgingServicingTripId(fromEncodedTripItemId: "not-base64!!!") == nil)
    #expect(ExpediaEnrichmentParser.hotelCancellationURL(fromServicingData: ["noop": true]) == nil)
    #expect(
        ExpediaProductType.catalogCancellationURL(
            bookingType: .hotel,
            manageURL: "https://www.expedia.de/trips/x/details/y/manage-booking"
        ) == nil
    )
    #expect(
        ExpediaProductType.catalogCancellationURL(
            bookingType: .carRental,
            manageURL: "https://www.expedia.de/trips/x/details/y/manage-booking"
        )?.hasSuffix("/manage-booking") == true
    )
    #expect(
        ExpediaProductType.catalogCancellationURL(
            bookingType: .flight,
            manageURL: "https://www.expedia.de/trips/x/details/y/manage-booking"
        ) == nil
    )
    #expect(
        ExpediaProductType.catalogCancellationURL(
            bookingType: .activity,
            manageURL: "https://www.expedia.de/trips/x/details/y/manage-booking"
        ) == nil
    )
}

@Test func expediaDraftApplySetsConfirmationCodeFromEnrichment() {
    var draft = ProviderBookingDraft(
        provider: .expedia,
        bookingType: .hotel,
        startAt: Date(timeIntervalSince1970: 1),
        endAt: Date(timeIntervalSince1970: 2)
    )
    #expect(draft.confirmationCode == nil)
    draft.apply(ProviderBookingEnrichment(confirmationCode: "L70REDACTED01"))
    #expect(draft.confirmationCode == "L70REDACTED01")
}
