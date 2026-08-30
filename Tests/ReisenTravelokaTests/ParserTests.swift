import Foundation
import Testing
import ReisenDomain
import ReisenProviders
@testable import ReisenTraveloka

private enum TravelokaFixtureLoader {
    /// Placeholders shared with `docs/fixtures/provider-research/traveloka_*_redacted.json`.
    static let redactedHotelBookingId = "REDACTED_HOTEL_BOOKING_ID"
    static let redactedExperienceBookingId = "REDACTED_EXPERIENCE_BOOKING_ID"
    static let redactedExperienceItineraryId = "REDACTED_EXPERIENCE_ITINERARY_ID"
    static let redactedVehicleBookingId = "REDACTED_VEHICLE_BOOKING_ID"
    static let redactedFlightBookingId = "REDACTED_FLIGHT_BOOKING_ID"

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
    #expect(activity.confirmationCode == TravelokaFixtureLoader.redactedExperienceBookingId)
    #expect(activity.title?.contains("Ha Noi") == true)
    #expect(activity.operatorName == "AXES")
    #expect(activity.isAllDay == true)
    #expect(activity.status == .confirmed)
    #expect(activity.externalUrl?.contains("type=EXPERIENCE") == true)
    #expect(activity.cancellationUrl?.contains("/refund/presubmission/EXPERIENCE/") == true)
    #expect(activity.cancellationUrl != activity.externalUrl)
    expectTravelokaPrice(activity.rateDetails, amount: 3.62)

    let hotel = try #require(byType[.hotel])
    #expect(hotel.confirmationCode == TravelokaFixtureLoader.redactedHotelBookingId)
    #expect(hotel.title?.contains("Example Hotel") == true)
    #expect(hotel.locationTo == "South Jakarta")
    #expect(hotel.locationToAddress?.contains("Cilandak") == true)
    #expect(hotel.rateDetails?.roomCategory == "Standard Double")
    #expect(hotel.rateDetails?.boardType == .roomOnly)
    expectTravelokaPrice(hotel.rateDetails, amount: 125.0)
    #expect(hotel.hotelCheckInMinutes == 14 * 60)
    #expect(hotel.deadlines.contains { $0.isFreeCancellation } == true)
    #expect(hotel.deadlines.contains { !$0.isFreeCancellation && $0.cancellationFeeAmount == 4.37 } == true)
    #expect(hotel.cancellationUrl?.contains("/refund/presubmission/") == true)
    #expect(hotel.cancellationUrl != hotel.externalUrl)
    // Catalog card often omits stay policies; Traveloka still enriches hotels with empty hints.
    #expect(hotel.guestHints.isEmpty)
    #expect(
        TravelokaDraftEnrichmentNeeds.shouldEnrich(hotel, requiresDeadlines: false) == true
    )

    let vehicle = try #require(byType[.carRental])
    #expect(vehicle.confirmationCode == TravelokaFixtureLoader.redactedVehicleBookingId)
    #expect(vehicle.title == "Daihatsu Sigra - Jakarta")
    #expect(vehicle.operatorName == "Jayamahe Easy Ride Jakarta")
    #expect(vehicle.locationFrom?.contains("Bandara") == true)
    #expect(vehicle.locationFromAddress?.contains("Jakarta") == true)
    #expect(vehicle.rateDetails?.roomCategory == "Automatic")
    expectTravelokaPrice(vehicle.rateDetails, amount: 89.0)
    #expect(vehicle.deadlines.contains { $0.isFreeCancellation } == true)
    #expect(vehicle.cancellationUrl?.contains("/refund/presubmission/") == true)
    #expect(vehicle.cancellationUrl != vehicle.externalUrl)

    let flight = try #require(catalog.bookings.first { $0.bookingType == .flight })
    #expect(flight.confirmationCode == TravelokaFixtureLoader.redactedFlightBookingId)
    #expect(flight.title?.contains("Jakarta") == true)
    expectTravelokaPrice(flight.rateDetails, amount: 450.0)
    #expect(flight.hotelOffsetSeconds == nil)
    #expect(flight.cancellationUrl?.contains("/refund/presubmission/") == true)
    #expect(flight.cancellationUrl != flight.externalUrl)
}

@Test func travelokaCatalogUsesCanonicalRoutePrefixInDetailURL() throws {
    let text = try TravelokaFixtureLoader.load("traveloka_itineraries_fetch_redacted.json")
    let catalog = try TravelokaCatalogParser.parse(from: text)
    let activity = try #require(catalog.bookings.first { $0.bookingType == .activity })
    #expect(
        activity.externalUrl?.contains(
            "/en-en/item/details/\(TravelokaFixtureLoader.redactedExperienceBookingId)"
        ) == true
    )
}

@Test func travelokaCatalogSkipsEntryWithoutTimestampsAndKeepsOthers() throws {
    let json = try travelokaCatalogJSON(entries: [
        travelokaCatalogHotelEntry(bookingId: "keep", timestamps: true),
        travelokaCatalogHotelEntry(bookingId: "skip", timestamps: false),
    ])
    let catalog = try TravelokaCatalogParser.parse(from: json)
    #expect(catalog.bookings.map(\.confirmationCode) == ["keep"])
}

@Test func travelokaCatalogSkipsEntryWithoutEndTimestampAndKeepsOthers() throws {
    let json = try travelokaCatalogJSON(entries: [
        travelokaCatalogHotelEntry(bookingId: "keep", timestamps: true),
        travelokaCatalogHotelEntry(bookingId: "skip-end", timestamps: true, includeEnd: false),
    ])
    let catalog = try TravelokaCatalogParser.parse(from: json)
    #expect(catalog.bookings.map(\.confirmationCode) == ["keep"])
}

@Test func travelokaEnrichmentThrowsWhenEndTimestampMissing() throws {
    let entry = travelokaCatalogHotelEntry(bookingId: "skip-end", timestamps: true, includeEnd: false)
    do {
        _ = try TravelokaItineraryEntryParser.enrichment(from: entry)
        Issue.record("Enrichment hätte missingItineraryTimestamps werfen müssen")
    } catch TravelokaProviderError.missingItineraryTimestamps {
        // Einzelfehler: fehlendes Ende ist kein Start-Klon.
    }
}

@Test func travelokaCatalogRethrowsMissingBookingIdentifiers() throws {
    let json = try travelokaCatalogJSON(entries: [
        travelokaCatalogHotelEntry(bookingId: "keep", timestamps: true),
        [
            "itineraryType": "HOTEL",
            "cardSummaryInfo": [
                "commonSummary": [
                    "itineraryTimestampBegin": 1_700_000_000_000,
                    "itineraryTimestampEnd": 1_700_086_400_000,
                ],
            ],
        ],
    ])
    do {
        _ = try TravelokaCatalogParser.parse(from: json)
        Issue.record("Katalog hätte missingBookingIdentifiers werfen müssen")
    } catch TravelokaProviderError.missingBookingIdentifiers {
        // Extract-Fehler darf den Katalog nicht still erfolgreich machen.
    }
}

private func travelokaCatalogJSON(entries: [[String: Any]]) throws -> String {
    let payload: [String: Any] = [
        "data": ["itineraryEntryList": entries],
    ]
    let data = try JSONSerialization.data(withJSONObject: payload)
    return String(decoding: data, as: UTF8.self)
}

private func travelokaCatalogHotelEntry(
    bookingId: String,
    timestamps: Bool,
    includeEnd: Bool = true
) -> [String: Any] {
    var common: [String: Any] = ["ianaTimezoneBegin": "Asia/Jakarta"]
    if timestamps {
        common["itineraryTimestampBegin"] = 1_700_000_000_000
        if includeEnd {
            common["itineraryTimestampEnd"] = 1_700_086_400_000
        }
    }
    return [
        "bookingId": bookingId,
        "itineraryId": "it-\(bookingId)",
        "itineraryType": "HOTEL",
        "cardSummaryInfo": [
            "commonSummary": common,
            "hotelSummary": ["hotelName": "Policy Hotel"],
        ],
        "cardDetailInfo": [:] as [String: Any],
    ]
}

private func travelokaPaymentInfo(
    amount: String,
    currency: String = "EUR",
    decimalPoint: String = "2",
    isTotalPriceHidden: Bool = false,
    totalPriceHidden: Bool = false
) -> [String: Any] {
    [
        "expectedAmount": [
            "currencyValue": ["currency": currency, "amount": amount],
            "numOfDecimalPoint": decimalPoint,
        ],
        "isTotalPriceHidden": isTotalPriceHidden,
        "totalPriceHidden": totalPriceHidden,
    ]
}

private func expectTravelokaPrice(
    _ rate: BookingRateDetails?,
    amount: Double,
    currency: String = "EUR"
) {
    #expect(rate?.totalPriceAmount == amount)
    #expect(rate?.totalPriceCurrency == currency)
}

@Test func travelokaHotelDeadlinesFromCancellationPoliciesArray() throws {
    let entry: [String: Any] = [
        "bookingId": "1",
        "itineraryId": "2",
        "itineraryType": "HOTEL",
        "cardSummaryInfo": [
            "commonSummary": [
                "itineraryTimestampBegin": 1_700_000_000_000,
                "itineraryTimestampEnd": 1_700_086_400_000,
                "ianaTimezoneBegin": "Asia/Jakarta",
            ],
            "hotelSummary": [
                "hotelName": "Policy Hotel",
                "checkInDate": ["day": 1, "month": 9, "year": 2026],
                "checkOutDate": ["day": 2, "month": 9, "year": 2026],
            ],
        ],
        "cardDetailInfo": [
            "hotelDetail": [
                "cancellationPolicies": [
                    ["type": "FREE", "deadlineLocal": "2026-09-01T12:59:00"],
                    ["type": "FEE", "deadlineLocal": "2026-09-01T12:59:00", "feeAmount": 4.37],
                ],
            ],
        ],
    ]
    let draft = try #require(try TravelokaItineraryEntryParser.draft(from: entry))
    #expect(draft.title == "Policy Hotel")
    #expect(draft.deadlines.count == 2)
    #expect(draft.deadlines.contains { $0.isFreeCancellation })
    #expect(draft.deadlines.contains { !$0.isFreeCancellation && $0.cancellationFeeAmount == 4.37 })
}

@Test func travelokaParsesOffsetTimezoneIdentifiers() {
    let offset = TravelokaJSON.timeZone(iana: "+07:00")
    #expect(offset?.secondsFromGMT() == 7 * 3600)
    #expect(TravelokaJSON.timeZone(iana: "UTC+07:00")?.secondsFromGMT() == 7 * 3600)
    #expect(TravelokaJSON.timeZone(iana: "GMT-05:30")?.secondsFromGMT() == -5 * 3600 - 30 * 60)
    #expect(TravelokaJSON.timeZone(iana: "Asia/Jakarta") != nil)
}

@Test func travelokaHotelDeadlinesFromCancellationPolicyInfos() throws {
    let entry: [String: Any] = [
        "bookingId": "1",
        "itineraryId": "2",
        "itineraryType": "HOTEL",
        "bookingInfo": [
            "hotelBookingInfo": [
                "hotelName": "Policy Infos Hotel",
                "cancellationPolicyInfos": [
                    [
                        "appliedDateInfoDescription": "01 Sep 2026 12:59",
                        "appliedEndDate": [
                            "hourMinute": ["hour": "12", "minute": "59"],
                            "monthDayYear": ["day": "1", "month": "9", "year": "2026"],
                        ],
                        "appliedStartDate": [
                            "hourMinute": ["hour": "2", "minute": "47"],
                            "monthDayYear": ["day": "27", "month": "8", "year": "2026"],
                        ],
                        "policyInfoDetail": [
                            "description": "Free cancellation before",
                            "fee": [
                                "currencyValue": ["amount": "0", "currency": "EUR"],
                                "numOfDecimalPoint": "2",
                            ],
                            "type": "FREE_CANCELLATION",
                        ],
                    ],
                    [
                        "appliedDateInfoDescription": "01 Sep 2026 12:59",
                        "appliedEndDate": [
                            "hourMinute": ["hour": "14", "minute": "0"],
                            "monthDayYear": ["day": "2", "month": "9", "year": "2026"],
                        ],
                        "appliedStartDate": [
                            "hourMinute": ["hour": "12", "minute": "59"],
                            "monthDayYear": ["day": "1", "month": "9", "year": "2026"],
                        ],
                        "policyInfoDetail": [
                            "description": "Cancellation fee €4.37 applies after",
                            "fee": [
                                "currencyValue": ["amount": "437", "currency": "EUR"],
                                "numOfDecimalPoint": "2",
                            ],
                            "type": "FULL_CHARGE",
                        ],
                    ],
                ],
            ],
        ],
        "cardSummaryInfo": [
            "commonSummary": [
                "itineraryTimestampBegin": 1_700_000_000_000,
                "itineraryTimestampEnd": 1_700_086_400_000,
                "ianaTimezoneBegin": "Asia/Jakarta",
            ],
        ],
        "cardDetailInfo": [
            "hotelDetail": [:],
        ],
    ]
    let draft = try #require(try TravelokaItineraryEntryParser.draft(from: entry))
    #expect(draft.deadlines.count == 2)
    #expect(draft.deadlines.contains { $0.isFreeCancellation })
    let fee = try #require(draft.deadlines.first { !$0.isFreeCancellation })
    #expect(fee.cancellationFeeAmount == 4.37)
    let tz = try #require(TimeZone(identifier: "Asia/Jakarta"))
    let expected = try #require(TravelokaJSON.localDateTime("2026-09-01T12:59:00", timeZone: tz))
    #expect(abs(draft.deadlines[0].deadlineAt.timeIntervalSince(expected)) < 0.01)
    #expect(abs(fee.deadlineAt.timeIntervalSince(expected)) < 0.01)
}

@Test func travelokaExperienceDeadlinesFromIndonesianPolicy() throws {
    let entry: [String: Any] = [
        "bookingId": "1",
        "itineraryId": "2",
        "itineraryType": "EXPERIENCE",
        "cardSummaryInfo": [
            "commonSummary": [
                "itineraryTimestampBegin": 1_700_000_000_000,
                "itineraryTimestampEnd": 1_700_086_400_000,
                "ianaTimezoneBegin": "Asia/Saigon",
            ],
            "experienceSummary": [
                "experienceName": "Ha Noi Double Decker Bus Pass",
                "ticketDate": ["day": 8, "month": 9, "year": 2026],
                "timeSlotId": "all_day_pass",
            ],
        ],
        "cardDetailInfo": [
            "experienceDetail": [
                "experienceName": "Ha Noi Double Decker Bus Pass",
                "ticketDate": ["day": 8, "month": 9, "year": 2026],
                "timeSlotId": "all_day_pass",
                "cancellationPolicies": [
                    "Semua pembatalan pesanan akan dikenakan biaya pembatalan.",
                    "Pembatalan yang dilakukan sekurang-kurangnya 1 hari sebelum tanggal kunjungan dapat di-refund hingga 100% dari harga dasar.",
                ],
            ],
        ],
    ]
    let draft = try #require(try TravelokaItineraryEntryParser.draft(from: entry))
    #expect(draft.deadlines.count == 1)
    #expect(draft.deadlines.first?.isFreeCancellation == true)
    let tz = try #require(TimeZone(identifier: "Asia/Saigon"))
    let visitEnd = try #require(TravelokaJSON.dateFromDay((2026, 9, 8), minutes: 23 * 60 + 59, timeZone: tz))
    let expected = try #require(Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: visitEnd))
    #expect(abs((draft.deadlines.first?.deadlineAt.timeIntervalSince(expected) ?? 99)) < 0.01)
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

    let missingBreakfast = baseEntry
    let draftUnknown = try #require(try TravelokaItineraryEntryParser.draft(from: missingBreakfast))
    #expect(draftUnknown.rateDetails?.boardType == .unknown)
    #expect(draftUnknown.rateDetails?.includedBreakfast == nil)

    var withFalse = baseEntry
    var summaryFalse = (withFalse["cardSummaryInfo"] as! [String: Any])
    var hotelSummaryFalse = (summaryFalse["hotelSummary"] as! [String: Any])
    hotelSummaryFalse["breakfastIncluded"] = false
    summaryFalse["hotelSummary"] = hotelSummaryFalse
    withFalse["cardSummaryInfo"] = summaryFalse
    let draftRoomOnly = try #require(try TravelokaItineraryEntryParser.draft(from: withFalse))
    #expect(draftRoomOnly.rateDetails?.boardType == .roomOnly)
    #expect(draftRoomOnly.rateDetails?.includedBreakfast == false)

    var withTrue = baseEntry
    var summaryTrue = (withTrue["cardSummaryInfo"] as! [String: Any])
    var hotelSummaryTrue = (summaryTrue["hotelSummary"] as! [String: Any])
    hotelSummaryTrue["breakfastIncluded"] = true
    summaryTrue["hotelSummary"] = hotelSummaryTrue
    withTrue["cardSummaryInfo"] = summaryTrue
    let draftBreakfast = try #require(try TravelokaItineraryEntryParser.draft(from: withTrue))
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
    expectTravelokaPrice(enrichment.rateDetails, amount: 3.62)
    #expect(enrichment.rateDetails?.roomCategory == "(Nighttime) Bus Pass Around Hanoi")
    #expect(enrichment.rateDetails?.guestCount == 1)
}

@Test func travelokaPaymentInfoExpectedAmountMapsToRateDetails() throws {
    var entry = travelokaCatalogHotelEntry(bookingId: "priced", timestamps: true)
    entry["paymentInfo"] = travelokaPaymentInfo(amount: "12500")
    let draft = try #require(try TravelokaItineraryEntryParser.draft(from: entry))
    expectTravelokaPrice(draft.rateDetails, amount: 125.0)
}

@Test func travelokaPaymentInfoHiddenFlagsLeavePriceNil() throws {
    let cases: [(String, [String: Any])] = [
        ("is", travelokaPaymentInfo(amount: "12500", isTotalPriceHidden: true)),
        ("total", travelokaPaymentInfo(amount: "12500", totalPriceHidden: true)),
    ]
    for (suffix, payment) in cases {
        var entry = travelokaCatalogHotelEntry(bookingId: "hidden-\(suffix)", timestamps: true)
        entry["paymentInfo"] = payment
        let draft = try #require(try TravelokaItineraryEntryParser.draft(from: entry))
        #expect(draft.rateDetails?.totalPriceAmount == nil)
        #expect(draft.rateDetails?.totalPriceCurrency == nil)
    }
}

@Test func travelokaHotelWithoutExpectedAmountDoesNotUseCancellationFeeAsPrice() throws {
    let entry: [String: Any] = [
        "bookingId": "1",
        "itineraryId": "2",
        "itineraryType": "HOTEL",
        "paymentInfo": [
            "userTripStatus": "ETICKET_PUBLISHED",
        ],
        "bookingInfo": [
            "hotelBookingInfo": [
                "hotelName": "Fee Only Hotel",
                "cancellationPolicyInfos": [
                    [
                        "appliedEndDate": [
                            "hourMinute": ["hour": "12", "minute": "59"],
                            "monthDayYear": ["day": "1", "month": "9", "year": "2026"],
                        ],
                        "policyInfoDetail": [
                            "description": "Cancellation fee",
                            "fee": [
                                "currencyValue": ["amount": "437", "currency": "EUR"],
                                "numOfDecimalPoint": "2",
                            ],
                            "type": "FULL_CHARGE",
                        ],
                    ],
                ],
            ],
        ],
        "cardSummaryInfo": [
            "commonSummary": [
                "itineraryTimestampBegin": 1_700_000_000_000,
                "itineraryTimestampEnd": 1_700_086_400_000,
                "ianaTimezoneBegin": "Asia/Jakarta",
            ],
            "hotelSummary": [
                "hotelName": "Fee Only Hotel",
                "roomName": "Standard",
            ],
        ],
        "cardDetailInfo": [:] as [String: Any],
    ]
    let draft = try #require(try TravelokaItineraryEntryParser.draft(from: entry))
    #expect(draft.rateDetails?.totalPriceAmount == nil)
    #expect(draft.deadlines.contains { !$0.isFreeCancellation && $0.cancellationFeeAmount == 4.37 })
}

@Test func travelokaEnrichmentHotelFromVoucherInfo() throws {
    let text = try TravelokaFixtureLoader.load("traveloka_itinerary_single_hotel_redacted.json")
    let enrichment = try TravelokaEnrichmentParser.parse(from: text)
    #expect(enrichment.title?.contains("Example Hotel") == true)
    #expect(enrichment.locationTo == "South Jakarta")
    #expect(enrichment.locationToAddress?.contains("Cilandak") == true)
    #expect(enrichment.hotelCheckInMinutes == 14 * 60)
    #expect(enrichment.hotelCheckOutMinutes == 12 * 60)
    #expect(enrichment.rateDetails?.roomCategory == "Standard Double")
    #expect(enrichment.rateDetails?.guestCount == 2)
    #expect(enrichment.rateDetails?.includedBreakfast == false)
    expectTravelokaPrice(enrichment.rateDetails, amount: 125.0)
    #expect(enrichment.deadlines.count == 2)
    #expect(enrichment.deadlines.contains { $0.isFreeCancellation } == true)
    let fee = try #require(enrichment.deadlines.first { !$0.isFreeCancellation })
    #expect(fee.cancellationFeeAmount == 4.37)
    let tz = try #require(TimeZone(identifier: "Asia/Jakarta"))
    let expected = try #require(TravelokaJSON.localDateTime("2026-09-01T12:59:00", timeZone: tz))
    #expect(abs((enrichment.deadlines.first { $0.isFreeCancellation }?.deadlineAt.timeIntervalSince(expected) ?? 99)) < 0.01)
    #expect(abs(fee.deadlineAt.timeIntervalSince(expected)) < 0.01)
    let hints = try #require(enrichment.guestHints)
    // Notices + propertyPolicy share near-identical copy; detail-dedup keeps distinct texts only.
    #expect(hints.count == 2)
    #expect(hints.contains { $0.sourceKey.contains("IMPORTANT_NOTICE") } == true)
    #expect(hints.contains { $0.detail.localizedCaseInsensitiveContains("marriage certificate") } == true)
    #expect(hints.contains { $0.detail.localizedCaseInsensitiveContains("unmarried couples") } == true)
    #expect(hints.contains { $0.sourceKey == "traveloka:property_policy" } == false)
    #expect(hints.contains { $0.sourceKey.contains("specialRequest") } == false)
}

@Test func travelokaProductType_heuristics_villaApartmentCar() {
    #expect(TravelokaProductType(raw: "VILLA").bookingType == .hotel)
    #expect(TravelokaProductType(raw: "APARTMENT").bookingType == .hotel)
    #expect(TravelokaProductType(raw: "CAR_RENTAL").bookingType == .carRental)
    #expect(TravelokaProductType(raw: "TRAINING").bookingType == .other)
}

@Test func travelokaEnrichmentVehicle() throws {
    let text = try TravelokaFixtureLoader.load("traveloka_itinerary_single_vehicle_redacted.json")
    let enrichment = try TravelokaEnrichmentParser.parse(from: text)
    #expect(enrichment.title == "Daihatsu Sigra - Jakarta")
    #expect(enrichment.operatorName == "Jayamahe Easy Ride Jakarta")
    #expect(enrichment.locationFrom?.contains("Bandara") == true)
    #expect(enrichment.locationFromAddress?.contains("Jakarta") == true)
    #expect(enrichment.locationToAddress?.contains("Jakarta") == true)
    #expect(enrichment.rateDetails?.roomCategory == "Automatic")
    expectTravelokaPrice(enrichment.rateDetails, amount: 89.0)
    #expect(enrichment.passengers?.first?.givenName == "REDACTED")
    #expect(enrichment.deadlines.count == 1)
    #expect(enrichment.deadlines.first?.isFreeCancellation == true)
    let tz = try #require(TimeZone(identifier: "Asia/Jakarta"))
    let pickup = try #require(TravelokaJSON.localDateTime("2026-09-07T09:00:00", timeZone: tz))
    let expected = try #require(Calendar(identifier: .gregorian).date(byAdding: .hour, value: -24, to: pickup))
    #expect(abs((enrichment.deadlines.first?.deadlineAt.timeIntervalSince(expected) ?? 99)) < 0.01)
}

@Test func travelokaEnrichmentFlightNonRefundable() throws {
    let text = try TravelokaFixtureLoader.load("traveloka_itinerary_single_flight_redacted.json")
    let enrichment = try TravelokaEnrichmentParser.parse(from: text)
    #expect(enrichment.title?.contains("Jakarta") == true)
    #expect(enrichment.rateDetails?.airline == "AirAsia")
    expectTravelokaPrice(enrichment.rateDetails, amount: 450.0)
    #expect(enrichment.deadlines.isEmpty)
    #expect(enrichment.flightDepartureOffsetSeconds != nil)
    #expect(enrichment.passengers?.count == 1)
    #expect(enrichment.passengers?.first?.travellerType == .adult)
    #expect(enrichment.locationFrom?.contains("CGK") == true)
    #expect(enrichment.locationFromAddress?.contains("Soekarno") == true)
    #expect(enrichment.locationFromAddress?.contains("Terminal") == true)
    #expect(enrichment.rateDetails?.baggageInfoRaw?.contains("Cabin") == true)
}

@Test func travelokaFlightParsesLiveBookingInfoSegments() throws {
    let entry: [String: Any] = [
        "bookingId": "1",
        "itineraryId": "2",
        "itineraryType": "FLIGHT",
        "bookingInfo": [
            "flightBookingInfo": [
                "bookingDetail": [
                    "sourceCity": "Singapore",
                    "destinationCity": "Bangkok",
                    "passengers": [
                        "adults": [["name": "REDACTED ADULT"]],
                        "children": [["name": "REDACTED CHILD", "typeDescription": "Child"]],
                        "infants": [],
                    ],
                    "segments": [
                        [
                            "airlineName": "Scoot",
                            "sourceAirport": [
                                "airportCode": "SIN",
                                "airportName": "Changi",
                                "location": "Singapore",
                                "terminalName": "1",
                            ],
                            "destinationAirport": [
                                "airportCode": "BKK",
                                "airportName": "Suvarnabhumi",
                                "location": "Bangkok",
                                "terminalName": "Main",
                            ],
                            "departureDateTime": [
                                "monthDayYear": ["year": "2026", "month": "10", "day": "1"],
                                "hourMinute": ["hour": "9", "minute": "30"],
                            ],
                            "arrivalDateTime": [
                                "monthDayYear": ["year": "2026", "month": "10", "day": "1"],
                                "hourMinute": ["hour": "11", "minute": "0"],
                            ],
                            "facilities": [
                                ["type": "cabinBaggage", "displayText": "7 kg"],
                            ],
                        ],
                    ],
                ],
            ],
        ],
        "flightTicketInfo": [
            "eTicketButtonInfo": ["buttonRefundAvailable": false],
        ],
        "cardSummaryInfo": [
            "commonSummary": [
                "itineraryTimestampBegin": 1_700_000_000_000,
                "itineraryTimestampEnd": 1_700_007_200_000,
                "ianaTimezoneBegin": "Asia/Singapore",
                "ianaTimezoneEnd": "Asia/Bangkok",
            ],
        ],
        "cardDetailInfo": [:],
    ]
    let draft = try #require(try TravelokaItineraryEntryParser.draft(from: entry))
    #expect(draft.title == "Singapore → Bangkok")
    #expect(draft.rateDetails?.airline == "Scoot")
    #expect(draft.rateDetails?.passengerCount == 2)
    #expect(draft.passengers.contains { $0.travellerType == .child })
    #expect(draft.locationFrom?.contains("SIN") == true)
    #expect(draft.locationToAddress?.contains("Suvarnabhumi") == true)
    #expect(draft.rateDetails?.baggageInfoRaw == "Cabin 7 kg")
    #expect(draft.deadlines.isEmpty)
    let tz = try #require(TimeZone(identifier: "Asia/Singapore"))
    let expected = try #require(TravelokaJSON.localDateTime("2026-10-01T09:30:00", timeZone: tz))
    #expect(abs(draft.startAt.timeIntervalSince(expected)) < 0.01)
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
    expectTravelokaPrice(enrichment.rateDetails, amount: 380.0)
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
    let bookingId = TravelokaFixtureLoader.redactedExperienceBookingId
    let itineraryId = TravelokaFixtureLoader.redactedExperienceItineraryId
    let url = "https://www.traveloka.com/en-en/item/details/\(bookingId)?type=EXPERIENCE&id=\(itineraryId)"
    let ids = try TravelokaExternalURL.detailIds(from: url)
    #expect(ids.bookingId == bookingId)
    #expect(ids.itineraryId == itineraryId)
    #expect(ids.productType == "EXPERIENCE")
}

@Test func travelokaEnrichmentCancelledStatus() throws {
    let text = try TravelokaFixtureLoader.load("traveloka_itinerary_single_cancelled_redacted.json")
    let enrichment = try TravelokaEnrichmentParser.parse(from: text)
    #expect(enrichment.status == .cancelled)
    #expect(enrichment.title?.contains("Cancelled Sample") == true)
    expectTravelokaPrice(enrichment.rateDetails, amount: 199.0)
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
    #expect(BookingStatus.parse(TravelokaStatusMapper.statusRaw(from: refundableEntry)) == .confirmed)
    #expect(BookingStatus.parse("Refundable") == .unknown)
    #expect(BookingStatus.parse("Non-cancellable") == .unknown)
    #expect(BookingStatus.parse("Booking cancelled") == .cancelled)
    #expect(BookingStatus.parse("REFUNDED") == .cancelled)
    #expect(BookingStatus.parse("CANCELLED") == .cancelled)
    #expect(BookingStatus.parse("ETICKET_PUBLISHED") == .confirmed)
    #expect(BookingStatus.parse("CANCELLATION_AVAILABLE") == .unknown)
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

@Test func travelokaSessionContextMapsMccIdCookieToHeader() {
    let mcc = HTTPCookie(properties: [
        .name: "tv_mcc_id",
        .value: "01M0WRDVH0NGPDPH4ZJJN0G4E7",
        .domain: ".traveloka.com",
        .path: "/",
    ])!
    let context = TravelokaSessionContext.from(cookies: [mcc])
    let headers = context.applying(to: [:])
    #expect(headers["tv-mcc-id"] == "01M0WRDVH0NGPDPH4ZJJN0G4E7")
}

@Test func travelokaCatalogFetchBodyUsesStandardAPIEnvelope() throws {
    let context = TravelokaSessionContext(sentinelToken: "sentinel-token-example")
    let data = try TravelokaAPI.catalogFetchBody(
        itineraryTypes: ["FLIGHT"],
        itineraryStatus: "UPCOMING",
        context: context
    )
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(json["fields"] as? [String] == [])
    #expect(json["clientInterface"] as? String == "desktop")
    let payload = try #require(json["data"] as? [String: Any])
    #expect(payload["itineraryTypes"] as? [String] == ["FLIGHT"])
    #expect(payload["itineraryStatus"] as? String == "UPCOMING")
    let sentinel = try #require(json["sentinel"] as? [String: Any])
    #expect(sentinel["token"] as? String == "sentinel-token-example")
}

@Test func draftEnrichmentNeedsSkipsCompleteCatalogDraft() {
    let complete = ProviderBookingDraft(
        provider: .traveloka,
        bookingType: .hotel,
        title: "Example Hotel",
        startAt: Date(),
        endAt: Date(),
        locationToAddress: "Jl. Example No. 1, Cilandak, South Jakarta",
        status: .confirmed,
        deadlines: [
            CancellationDeadline(
                deadlineAt: Date(),
                policyText: "Free",
                isFreeCancellation: true
            ),
            CancellationDeadline(
                deadlineAt: Date(),
                policyText: "Fee",
                isFreeCancellation: false,
                cancellationFeeAmount: 4.37
            ),
        ],
        rateDetails: BookingRateDetails(roomCategory: "Standard Double"),
        hotelCheckInMinutes: 14 * 60,
        hotelCheckOutMinutes: 12 * 60,
        guestHints: [
            BookingGuestHint(
                title: "Hausregeln",
                detail: "Unmarried couples are not allowed.",
                sourceKey: "traveloka:property_policy",
                providerRaw: ProviderID.traveloka.rawValue
            ),
        ]
    )
    #expect(DraftEnrichmentNeeds.shouldEnrich(complete, requiresDeadlines: true) == false)
    #expect(TravelokaDraftEnrichmentNeeds.shouldEnrich(complete, requiresDeadlines: true) == false)

    var completeWithoutHints = complete
    completeWithoutHints.guestHints = []
    #expect(DraftEnrichmentNeeds.shouldEnrich(completeWithoutHints, requiresDeadlines: true) == false)
    #expect(TravelokaDraftEnrichmentNeeds.shouldEnrich(completeWithoutHints, requiresDeadlines: true) == true)

    let missingCheckIn = ProviderBookingDraft(
        provider: .traveloka,
        bookingType: .hotel,
        startAt: Date(),
        endAt: Date(),
        status: .confirmed,
        deadlines: complete.deadlines,
        hotelCheckOutMinutes: 12 * 60
    )
    #expect(DraftEnrichmentNeeds.shouldEnrich(missingCheckIn, requiresDeadlines: true) == true)
    #expect(TravelokaDraftEnrichmentNeeds.shouldEnrich(missingCheckIn, requiresDeadlines: true) == true)

    let missingAddress = ProviderBookingDraft(
        provider: .traveloka,
        bookingType: .hotel,
        title: "Example Hotel",
        startAt: Date(),
        endAt: Date(),
        status: .confirmed,
        deadlines: complete.deadlines,
        rateDetails: BookingRateDetails(roomCategory: "Standard Double"),
        hotelCheckInMinutes: 14 * 60,
        hotelCheckOutMinutes: 12 * 60
    )
    #expect(DraftEnrichmentNeeds.shouldEnrich(missingAddress, requiresDeadlines: true) == true)

    let completeCarRental = ProviderBookingDraft(
        provider: .traveloka,
        bookingType: .carRental,
        title: "Daihatsu Sigra - Jakarta",
        startAt: Date(),
        endAt: Date(),
        locationFrom: "Bandara",
        locationTo: "Jakarta",
        locationFromAddress: "Pickup Jakarta",
        locationToAddress: "Dropoff Jakarta",
        operatorName: "Jayamahe",
        status: .confirmed
    )
    #expect(DraftEnrichmentNeeds.shouldEnrich(completeCarRental, requiresDeadlines: false) == false)
    #expect(TravelokaDraftEnrichmentNeeds.shouldEnrich(completeCarRental, requiresDeadlines: false) == false)

    let missingCarPickup = ProviderBookingDraft(
        provider: .traveloka,
        bookingType: .carRental,
        title: "Daihatsu Sigra - Jakarta",
        startAt: Date(),
        endAt: Date(),
        locationTo: "Jakarta",
        locationFromAddress: "Pickup Jakarta",
        locationToAddress: "Dropoff Jakarta",
        operatorName: "Jayamahe",
        status: .confirmed
    )
    #expect(DraftEnrichmentNeeds.shouldEnrich(missingCarPickup, requiresDeadlines: false) == true)
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

    #expect(context.resolvedRoutePrefix == "en-en")
    #expect(context.resolvedLanguage == "en_EN")
    #expect(context.resolvedCountry == "EN")
    #expect(context.resolvedCurrency == "IDR")

    let headers = context.applying(to: [:])
    #expect(headers["tv-language"] == "en_EN")
    #expect(headers["tv-country"] == "EN")
    #expect(headers["tv-currency"] == "IDR")
    #expect(headers["x-route-prefix"] == "en-en")
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

@Test func travelokaRefundMergeKeepsExistingFreeAndAddsFee() {
    let tz = TimeZone(secondsFromGMT: 7 * 3600)!
    let freeAt = Date(timeIntervalSince1970: 1_700_000_000)
    let feeAt = Date(timeIntervalSince1970: 1_700_086_400)
    let existing = [
        TravelokaCancellationDeadlines.at(
            freeAt,
            timeZone: tz,
            policyText: "Free cancellation",
            isFreeCancellation: true
        ),
    ]
    let refund = [
        TravelokaCancellationDeadlines.at(
            Date(timeIntervalSince1970: 1_699_000_000),
            timeZone: tz,
            policyText: "Refund free (must not replace itinerary free)",
            isFreeCancellation: true
        ),
        TravelokaCancellationDeadlines.at(
            feeAt,
            timeZone: tz,
            policyText: "Full charge",
            isFreeCancellation: false,
            feeAmount: 12.5
        ),
    ]
    let merged = existing.combining(refund: refund)
    #expect(merged.count == 2)
    let free = merged.first { $0.isFreeCancellation }
    #expect(free?.deadlineAt == freeAt)
    #expect(free?.policyText == "Free cancellation")
    let fee = merged.first { !$0.isFreeCancellation }
    #expect(fee?.deadlineAt == feeAt)
    #expect(fee?.cancellationFeeAmount == 12.5)
}

@Test func travelokaLocalizedMapPrefersEnglishThenSortedKey() {
    #expect(TravelokaJSON.preferredLocaleMapKey(from: ["th_TH", "id_ID"]) == "id_ID")
    #expect(TravelokaJSON.preferredLocaleMapKey(from: ["id_ID", "en_EN", "en_US"]) == "en_EN")

    let withoutEnglish: [String: Any] = [
        "th_TH": ["pnrCode": "TH"],
        "id_ID": ["pnrCode": "ID"],
    ]
    #expect(TravelokaJSON.localizedMapValue(withoutEnglish)["pnrCode"] as? String == "ID")

    let withEnglish: [String: Any] = [
        "id_ID": ["pnrCode": "ID"],
        "en_EN": ["pnrCode": "EN"],
    ]
    #expect(TravelokaJSON.localizedMapValue(withEnglish)["pnrCode"] as? String == "EN")

    let voucher: [String: Any] = [
        "localeAwareInfos": [
            ["locale": "th_TH", "hotelName": "TH"],
            ["locale": "id_ID", "hotelName": "ID"],
        ],
    ]
    #expect(TravelokaJSON.localeAwareInfo(from: voucher)["hotelName"] as? String == "ID")
}

@Test func travelokaJSONValueSkipsNSNullAndReadsLaterDict() {
    let first: [String: Any] = ["hotelName": NSNull()]
    let second: [String: Any] = ["hotelName": "Example Hotel"]
    #expect(TravelokaJSON.string(fromKeys: ["hotelName"], in: [first, second]) == "Example Hotel")
}

@Test func travelokaFlightParsesBookingDetailRoutesWhenSegmentsMissing() throws {
    let entry: [String: Any] = [
        "bookingId": "1",
        "itineraryId": "2",
        "itineraryType": "FLIGHT",
        "bookingInfo": [
            "flightBookingInfo": [
                "bookingDetail": [
                    "sourceCity": "Singapore",
                    "destinationCity": "Bangkok",
                    "routes": [
                        [
                            "segments": [
                                [
                                    "airlineName": "Scoot",
                                    "sourceAirport": [
                                        "airportCode": "SIN",
                                        "location": "Singapore",
                                    ],
                                    "destinationAirport": [
                                        "airportCode": "BKK",
                                        "location": "Bangkok",
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
        ],
        "cardSummaryInfo": [
            "commonSummary": [
                "itineraryTimestampBegin": 1_700_000_000_000,
                "itineraryTimestampEnd": 1_700_007_200_000,
                "ianaTimezoneBegin": "Asia/Singapore",
                "ianaTimezoneEnd": "Asia/Bangkok",
            ],
        ],
        "cardDetailInfo": [:],
    ]
    let draft = try #require(try TravelokaItineraryEntryParser.draft(from: entry))
    #expect(draft.title == "Singapore → Bangkok")
    #expect(draft.rateDetails?.airline == "Scoot")
    #expect(draft.locationFrom?.contains("SIN") == true)
    #expect(draft.locationTo?.contains("BKK") == true)
}

@Test func travelokaFlightParsesFlightRouteGroupsWhenSegmentsMissing() throws {
    let entry: [String: Any] = [
        "bookingId": "1",
        "itineraryId": "2",
        "itineraryType": "FLIGHT",
        "bookingInfo": [
            "flightBookingInfo": [
                "bookingDetail": [
                    "flightRouteGroups": [
                        [
                            "routes": [
                                [
                                    "segments": [
                                        [
                                            "brandName": "Scoot",
                                            "departureCity": "Singapore",
                                            "departureCityCode": "SIN",
                                            "arrivalCity": "Bangkok",
                                            "arrivalCityCode": "BKK",
                                        ],
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
        ],
        "cardSummaryInfo": [
            "commonSummary": [
                "itineraryTimestampBegin": 1_700_000_000_000,
                "itineraryTimestampEnd": 1_700_007_200_000,
                "ianaTimezoneBegin": "Asia/Singapore",
                "ianaTimezoneEnd": "Asia/Bangkok",
            ],
        ],
        "cardDetailInfo": [:],
    ]
    let draft = try #require(try TravelokaItineraryEntryParser.draft(from: entry))
    #expect(draft.title == "Singapore → Bangkok")
    #expect(draft.rateDetails?.airline == "Scoot")
    #expect(draft.locationFrom?.contains("SIN") == true)
    #expect(draft.locationTo?.contains("BKK") == true)
}

@Test func travelokaProductType_train_mapsToTrain() {
    #expect(TravelokaProductType(raw: "TRAIN").bookingType == .train)
    #expect(TravelokaProductType(raw: "TRAIN_GLOBAL").bookingType == .train)
    #expect(TravelokaProductType.train.rawValue == "TRAIN")
    #expect(TravelokaProductType.trainGlobal.rawValue == "TRAIN_GLOBAL")
    #expect(TravelokaProductType(raw: "TRAINING").bookingType == .other)
}

@Test func travelokaTrainDraft_mapsBookingTypeAndProductName() throws {
    let entry: [String: Any] = [
        "bookingId": "train-1",
        "itineraryId": "train-2",
        "itineraryType": "TRAIN",
        "cardSummaryInfo": [
            "commonSummary": [
                "productName": "Argo Bromo",
                "itineraryTimestampBegin": 1_700_000_000_000,
                "itineraryTimestampEnd": 1_700_014_400_000,
                "ianaTimezoneBegin": "Asia/Jakarta",
                "ianaTimezoneEnd": "Asia/Jakarta",
            ],
            "trainSummary": nil,
        ],
        "cardDetailInfo": [
            "trainDetail": nil,
        ],
    ]
    let draft = try #require(try TravelokaItineraryEntryParser.draft(from: entry))
    #expect(draft.bookingType == .train)
    #expect(draft.title == "Argo Bromo")
    #expect(draft.locationFrom == nil)
    #expect(draft.locationTo == nil)
    #expect(draft.externalUrl?.contains("type=TRAIN") == true)
    #expect(draft.hotelOffsetSeconds == nil)
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let end = Date(timeIntervalSince1970: 1_700_014_400)
    let jakarta = try #require(TimeZone(identifier: "Asia/Jakarta"))
    #expect(draft.flightDepartureOffsetSeconds == jakarta.secondsFromGMT(for: start))
    #expect(draft.flightArrivalOffsetSeconds == jakarta.secondsFromGMT(for: end))
}

@Test func travelokaTrainDraft_withoutIanaLeavesFlightOffsetsNil() throws {
    let entry: [String: Any] = [
        "bookingId": "train-1",
        "itineraryId": "train-2",
        "itineraryType": "TRAIN",
        "cardSummaryInfo": [
            "commonSummary": [
                "productName": "Argo Bromo",
                "itineraryTimestampBegin": 1_700_000_000_000,
                "itineraryTimestampEnd": 1_700_014_400_000,
            ],
        ],
        "cardDetailInfo": [:],
    ]
    let draft = try #require(try TravelokaItineraryEntryParser.draft(from: entry))
    #expect(draft.bookingType == .train)
    #expect(draft.flightDepartureOffsetSeconds == nil)
    #expect(draft.flightArrivalOffsetSeconds == nil)
}

@Test func travelokaTrainDraft_mapsBeginAndEndTimeZonesSeparately() throws {
    let entry: [String: Any] = [
        "bookingId": "train-1",
        "itineraryId": "train-2",
        "itineraryType": "TRAIN_GLOBAL",
        "cardSummaryInfo": [
            "commonSummary": [
                "productName": "Singapore → Bangkok",
                "itineraryTimestampBegin": 1_700_000_000_000,
                "itineraryTimestampEnd": 1_700_014_400_000,
                "ianaTimezoneBegin": "Asia/Singapore",
                "ianaTimezoneEnd": "Asia/Bangkok",
            ],
        ],
        "cardDetailInfo": [:],
    ]
    let draft = try #require(try TravelokaItineraryEntryParser.draft(from: entry))
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let end = Date(timeIntervalSince1970: 1_700_014_400)
    let singapore = try #require(TimeZone(identifier: "Asia/Singapore"))
    let bangkok = try #require(TimeZone(identifier: "Asia/Bangkok"))
    #expect(draft.flightDepartureOffsetSeconds == singapore.secondsFromGMT(for: start))
    #expect(draft.flightArrivalOffsetSeconds == bangkok.secondsFromGMT(for: end))
    #expect(draft.flightDepartureOffsetSeconds != draft.flightArrivalOffsetSeconds)
}

@Test func travelokaVehicleParsesIndonesian24hFreeCancellation() throws {
    let entry: [String: Any] = [
        "bookingId": "1",
        "itineraryId": "2",
        "itineraryType": "VEHICLE_RENTAL",
        "cardSummaryInfo": [
            "commonSummary": [
                "itineraryTimestampBegin": 1_700_000_000_000,
                "itineraryTimestampEnd": 1_700_086_400_000,
                "ianaTimezoneBegin": "Asia/Jakarta",
                "ianaTimezoneEnd": "Asia/Jakarta",
            ],
            "vehicleRentalSummaryInfo": [
                "vehicleName": "Daihatsu Sigra",
                "routeName": "Jakarta",
            ],
        ],
        "cardDetailInfo": [
            "vehicleRentalDetailInfo": [
                "startDate": ["year": "2026", "month": "9", "day": "7"],
                "pickupTime": "09:00",
                "refundInfo": [
                    "Pembatalan gratis 24 jam sebelum waktu penjemputan.",
                ],
            ],
        ],
    ]
    let draft = try #require(try TravelokaItineraryEntryParser.draft(from: entry))
    #expect(draft.bookingType == .carRental)
    #expect(draft.deadlines.count == 1)
    #expect(draft.deadlines.first?.isFreeCancellation == true)
    let tz = try #require(TimeZone(identifier: "Asia/Jakarta"))
    let pickup = try #require(TravelokaJSON.localDateTime("2026-09-07T09:00:00", timeZone: tz))
    let expected = try #require(Calendar(identifier: .gregorian).date(byAdding: .hour, value: -24, to: pickup))
    #expect(abs((draft.deadlines.first?.deadlineAt.timeIntervalSince(expected) ?? 99)) < 0.01)
}
