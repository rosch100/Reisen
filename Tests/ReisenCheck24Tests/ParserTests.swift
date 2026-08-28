import Testing
import Foundation
@testable import ReisenCheck24
import ReisenDomain
import ReisenProviders

@Test("ActivityListParser schließt stornierte und vergangene Buchungen aus")
func activityListExcludesCancelledAndPast() throws {
    let json = """
    {
      "activities": [
        {
          "startDate": "2099-08-11T23:59:00",
          "endDate": "2099-08-14T12:00:00",
          "status": { "key": "upcoming" },
          "product": { "key": "hotel" },
          "detail": { "line1": "Zukunft Hotel" },
          "link": { "link": "https://hotel.check24.de/kundenbereich/buchung/11111111-1111-1111-1111-111111111111" }
        },
        {
          "startDate": "2026-08-20T23:59:00",
          "endDate": "2026-08-21T12:00:00",
          "status": { "key": "cancelled" },
          "product": { "key": "hotel" },
          "detail": { "line1": "Storniert Hotel" },
          "link": { "link": "https://hotel.check24.de/kundenbereich/buchung/22222222-2222-2222-2222-222222222222" }
        },
        {
          "startDate": "2025-01-01T00:00:00",
          "endDate": "2025-01-02T00:00:00",
          "status": { "key": "ended" },
          "product": { "key": "hotel" },
          "detail": { "line1": "Vergangen Hotel" },
          "link": { "link": "https://hotel.check24.de/kundenbereich/buchung/33333333-3333-3333-3333-333333333333" }
        }
      ]
    }
    """

    let parsed = try ActivityListParser().parseActivityListHTML(json)
    #expect(parsed.bookings.count == 1)
    #expect(parsed.bookings[0].title == "Zukunft Hotel")
}

@Test("ActivityListParser parst Hotel-ISO mit Offset-Suffix über Datumspräfix")
func activityListParsesHotelISODateWithOffsetSuffix() throws {
    let json = """
    {
      "activities": [
        {
          "startDate": "2099-08-11T00:00:00+07:00",
          "endDate": "2099-08-14T12:00:00+07:00",
          "status": { "key": "upcoming" },
          "product": { "key": "hotel" },
          "detail": { "line1": "Offset Hotel" },
          "link": { "link": "https://hotel.check24.de/kundenbereich/buchung/44444444-4444-4444-4444-444444444444" }
        }
      ]
    }
    """
    let parsed = try ActivityListParser().parseActivityListHTML(json)
    #expect(parsed.bookings.count == 1)
    #expect(parsed.bookings[0].title == "Offset Hotel")
    #expect(parsed.bookings[0].startAt == HotelStayDate.parse("2099-08-11T00:00:00+07:00"))
}

@Test("ActivityListParser: Hotel-HAR-Abend wird vor dem Today-Gate zum Kalendertag")
func activityListParseCatalogDate_hotelHarEveningIsCalendarDay() throws {
    let parser = ActivityListParser()
    let raw = "Tue Aug 11 2026 23:59:00 GMT+0200"
    let flexible = try #require(parser.parseFlexibleDate(raw))
    let parsed = try #require(parser.parseCatalogDate(raw, bookingType: .hotel))
    #expect(parsed == HotelStayDate.calendarDay(fromParsed: flexible))
}

@Test("ActivityListParser: Hotel-Kalendertag gestern bleibt draußen, auch bei T23:59")
func activityListHotelYesterdayEveningDoesNotPassTodayGate() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 27, hour: 12))!
    let activity: [String: Any] = [
        "startDate": "2026-08-26T23:59:00",
        "endDate": "2026-08-28T12:00:00",
        "status": ["key": "upcoming"],
        "product": ["key": "hotel"],
        "detail": ["line1": "Gestern Hotel"],
        "link": ["link": "https://hotel.check24.de/kundenbereich/buchung/55555555-5555-5555-5555-555555555555"]
    ]
    let parsed = ActivityListParser().parseOneActivityIfRelevant(activity, now: now)
    #expect(parsed == nil)
}

@Test("ActivityListParser: leeres activities-Array ist leerer Katalog")
func activityListEmptyJSONIsEmptyCatalog() throws {
    let parsed = try ActivityListParser().parseActivityListHTML("""
    { "activities": [] }
    """)
    #expect(parsed.bookings.isEmpty)
}

@Test("ActivityListParser: nur stornierte/vergangene Buchungen sind leerer Katalog")
func activityListOnlyCancelledAndPastIsEmptyCatalog() throws {
    let json = """
    {
      "activities": [
        {
          "startDate": "2026-08-20T23:59:00",
          "endDate": "2026-08-21T12:00:00",
          "status": { "key": "cancelled" },
          "product": { "key": "hotel" },
          "detail": { "line1": "Storniert Hotel" },
          "link": { "link": "https://hotel.check24.de/kundenbereich/buchung/22222222-2222-2222-2222-222222222222" }
        },
        {
          "startDate": "2025-01-01T00:00:00",
          "endDate": "2025-01-02T00:00:00",
          "status": { "key": "ended" },
          "product": { "key": "hotel" },
          "detail": { "line1": "Vergangen Hotel" },
          "link": { "link": "https://hotel.check24.de/kundenbereich/buchung/33333333-3333-3333-3333-333333333333" }
        }
      ]
    }
    """
    let parsed = try ActivityListParser().parseActivityListHTML(json)
    #expect(parsed.bookings.isEmpty)
}

@Test("ActivityListParser: HTML ohne Buchungslinks ist leerer Katalog")
func activityListHTMLWithoutBookingLinksIsEmptyCatalog() throws {
    let parsed = try ActivityListParser().parseActivityListHTML(
        "<html><body><p>Keine Buchungen</p></body></html>"
    )
    #expect(parsed.bookings.isEmpty)
}

@Test("Check24: Login-HTML wird als fehlende Session erkannt")
func check24LoginHTMLIndicatesMissingSession() {
    let loginHTML = """
    <html><body>
    <form action="https://kundenbereich.check24.de/user/login.html">
    <input type="password" name="password">
    </form>
    </body></html>
    """
    #expect(AuthPageHTMLHeuristic.check24LooksLikeLoginHTML(loginHTML))
    #expect(!AuthPageHTMLHeuristic.check24LooksLikeLoginHTML(#"{ "activities": [] }"#))
    #expect(!AuthPageHTMLHeuristic.check24LooksLikeLoginHTML(
        "<html><body><a href=\"/user/account/activities.html\">Aktivitäten</a></body></html>"
    ))
}

@Test("Check24 Provider: Snapshot ohne Daten ist leerer Katalog, kein Fehler")
@MainActor
func check24ProviderEmptySnapshotIsEmptyCatalog() throws {
    let provider = Check24TravelProvider()
    let parsed = try provider.parseCatalogAllowingEmpty(
        "<html><body><a href=\"/hotel\">Nav</a></body></html>"
    )
    #expect(parsed.bookings.isEmpty)
}

@Test("Check24DeepLinkBuilder erzeugt Hotel-URL aus Destination-Hint")
func deepLinkHotelURL() {
    let context = GapContext(
        gapStart: Date(timeIntervalSince1970: 1_800_000_000),
        gapEnd: Date(timeIntervalSince1970: 1_800_086_400),
        kind: .lodging,
        fromLocationFrom: nil,
        fromLocationTo: "Side-81907",
        toLocationFrom: nil,
        toLocationTo: nil
    )
    let result = Check24DeepLinkBuilder().suggestions(for: context)
    #expect(result.links.contains(where: { $0.url?.absoluteString.contains("hotel.check24.de/search/Side-81907") == true }))
    #expect(result.links.allSatisfy { $0.category == .hotel })
    #expect(!result.issues.contains(.missingFromIATA))
}

@Test("Check24DeepLinkBuilder Flug: Ankunft der vorherigen → Ort der nächsten Buchung")
func deepLinkFlightUsesArrivalThenNextOrigin() {
    let context = GapContext(
        gapStart: Date(timeIntervalSince1970: 1_800_000_000),
        gapEnd: Date(timeIntervalSince1970: 1_800_086_400),
        kind: .transport,
        fromLocationFrom: "FRA",
        fromLocationTo: "MUC",
        toLocationFrom: "PMI",
        toLocationTo: "TXL"
    )
    let result = Check24DeepLinkBuilder().suggestions(for: context)
    let flight = result.links.first { $0.category == .flight }
    let url = flight?.url?.absoluteString ?? ""
    #expect(url.contains("from_0=MUC-C"))
    #expect(url.contains("to_0=PMI-C"))
    #expect(!url.contains("from_0=FRA-C"))
    #expect(!url.contains("to_0=TXL-C"))
}

@Test("Check24DeepLinkBuilder Flug: Fallback nutzt Stadtname statt IATA")
func deepLinkFlightCityFallback() {
    let context = GapContext(
        gapStart: Date(timeIntervalSince1970: 1_800_000_000),
        gapEnd: Date(timeIntervalSince1970: 1_800_086_400),
        kind: .transport,
        fromLocationFrom: nil,
        fromLocationTo: "JOG",
        toLocationFrom: nil,
        toLocationTo: "Yogyakarta"
    )

    let result = Check24DeepLinkBuilder().suggestions(for: context)
    let flight = result.links.first { $0.category == .flight }
    let url = flight?.url?.absoluteString ?? ""

    #expect(!url.isEmpty)
    #expect(url.contains("from_0=JOG-C"))
    #expect(url.contains("to_0=YOGYAKARTA-C"))
}

@Test("BookingDetailsParser nimmt effectivePrice statt basketPrice")
func bookingDetailsParserPrefersEffectivePriceJson() {
    let html = """
    <html>
      <div>effektiver Preis: 448,83 €</div>
      <script>
        {"basketPrice":{"amount":448.83},"effectivePrice":{"amount":203.83}}
      </script>
    </html>
    """

    let parsed = BookingDetailsParser().parse(from: html, bookingType: .hotel)
    #expect(parsed.totalPriceAmount == 203.83)
    #expect(parsed.totalPriceCurrency == "EUR")
}

@Test("BookingDetailsParser kann integer effectivePrice parsen")
func bookingDetailsParserParsesIntegerEffectivePriceJson() {
    let html = """
    <html>
      <div>effektiver Preis: 448,83 €</div>
      <script>
        {"basketPrice":{"amount":448.83},"effectivePrice":{"amount":235}}
      </script>
    </html>
    """

    let parsed = BookingDetailsParser().parse(from: html, bookingType: .hotel)
    #expect(parsed.totalPriceAmount == 235.0)
    #expect(parsed.totalPriceCurrency == "EUR")
}

@Test("BookingDetailsParser fall-back nutzt effektiver Preis Label")
func bookingDetailsParserFallsBackToChooserLabel() {
    let html = """
    <html>
      <div>effektiver Preis: 144,69 €</div>
    </html>
    """

    let parsed = BookingDetailsParser().parse(from: html, bookingType: .hotel)
    #expect(parsed.totalPriceAmount == 144.69)
    #expect(parsed.totalPriceCurrency == "EUR")
}

@Test("ActivityListParser baut Details aus payment.amount pro Zimmer")
func activityListParserParsesPaymentIntoDetails() throws {
    let json = """
    {
      "activities": [
        {
          "startDate": "2099-08-11T23:59:00",
          "endDate": "2099-08-14T12:00:00",
          "status": { "key": "upcoming" },
          "product": { "key": "hotel" },
          "detail": { "line1": "Hotel Mimpi" },
          "link": { "link": "https://hotel.check24.de/kundenbereich/buchung/11111111-1111-1111-1111-111111111111" },
          "payment": { "amount": "203,83", "prefix": "effektiv", "suffix": "€" },
          "product_specific_data": { "sso_room_text": "1x Doppelzimmer" }
        },
        {
          "startDate": "2099-08-11T23:59:00",
          "endDate": "2099-08-14T12:00:00",
          "status": { "key": "upcoming" },
          "product": { "key": "hotel" },
          "detail": { "line1": "Hotel Mimpi" },
          "link": { "link": "https://hotel.check24.de/kundenbereich/buchung/22222222-2222-2222-2222-222222222222" },
          "payment": { "amount": "235,00", "prefix": "effektiv", "suffix": "€" },
          "product_specific_data": { "sso_room_text": "1x Doppelzimmer" }
        }
      ]
    }
    """

    let parsed = try ActivityListParser().parseActivityListHTML(json)
    #expect(parsed.bookings.count == 2)
    #expect(parsed.bookings[0].details != nil)
    #expect(abs((parsed.bookings[0].details?.totalPriceAmount ?? 0) - 203.83) < 0.001)
    #expect(parsed.bookings[1].details != nil)
    #expect(abs((parsed.bookings[1].details?.totalPriceAmount ?? 0) - 235.0) < 0.001)
}

@Test("Check24 UUID-Fallback nutzt Host nach Produkttyp")
func activityListUUIDFallbackUsesProductHost() throws {
    let json = """
    {
      "activities": [
        {
          "startDate": "2099-09-01T10:00:00",
          "endDate": "2099-09-01T14:00:00",
          "status": { "key": "upcoming" },
          "product": { "key": "flight" },
          "detail": { "line1": "FRA-PMI" },
          "booking_uuid": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        },
        {
          "startDate": "2099-09-02T10:00:00",
          "endDate": "2099-09-02T18:00:00",
          "status": { "key": "upcoming" },
          "product": { "key": "ferry" },
          "detail": { "line1": "Fähre" },
          "product_specific_data": { "booking_uuid": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb" }
        },
        {
          "startDate": "2099-09-03T00:00:00",
          "endDate": "2099-09-05T00:00:00",
          "status": { "key": "upcoming" },
          "product": { "key": "hotel" },
          "detail": { "line1": "Hotel" },
          "booking_uuid": "cccccccc-cccc-cccc-cccc-cccccccccccc"
        }
      ]
    }
    """

    let parsed = try ActivityListParser().parseActivityListHTML(json)
    #expect(parsed.bookings.count == 3)
    let byType = Dictionary(uniqueKeysWithValues: parsed.bookings.map { ($0.type, $0.externalUrl) })
    #expect(byType[.flight] == "https://flug.check24.de/kundenbereich/buchung/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
    #expect(byType[.ferry] == "https://ferry.check24.de/kundenbereich/buchung/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
    #expect(byType[.hotel] == "https://hotel.check24.de/kundenbereich/buchung/cccccccc-cccc-cccc-cccc-cccccccccccc")
    for booking in parsed.bookings {
        #expect(BookingExternalURL.browserURL(from: booking.externalUrl) != nil)
    }
}

@Test("Check24 Normalize: UUID-Buchungs-URL ohne Host-Token nutzt BookingType")
func check24NormalizeUsesBookingTypeWhenHostAmbiguous() {
    let parser = ActivityListParser()
    let raw = "https://kundenbereich.check24.de/kundenbereich/buchung/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    let flight = parser.normalizeBookingDetailURL(raw, bookingType: .flight)
    let ferry = parser.normalizeBookingDetailURL(raw, bookingType: .ferry)
    #expect(flight == "https://flug.check24.de/kundenbereich/buchung/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
    #expect(ferry == "https://ferry.check24.de/kundenbereich/buchung/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
}
