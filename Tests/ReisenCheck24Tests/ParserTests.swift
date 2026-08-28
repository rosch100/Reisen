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
    #expect(AuthPageHTMLHeuristic.check24LooksLikeLoginHTML(
        loginHTML,
        responseURL: URL(string: "https://kundenbereich.check24.de/user/login.html")
    ))
    #expect(!AuthPageHTMLHeuristic.check24LooksLikeLoginHTML(
        loginHTML,
        responseURL: URL(string: "https://kundenbereich.check24.de/user/account/activities.html")
    ))
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
    let flight = result.links.first { $0.title.contains("Flug suchen") }
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
    let flight = result.links.first { $0.title.contains("Flug suchen") }
    let url = flight?.url?.absoluteString ?? ""

    #expect(!url.isEmpty)
    #expect(url.contains("from_0=JOG-C"))
    #expect(url.contains("to_0=YOGYAKARTA-C"))
}

@Test("Check24DeepLinkBuilder Mietwagen: Jumpin mit Ortsnamen, Hotel-ID abgestreift")
func deepLinkCarRentalJumpinUsesPlaceNames() {
    let context = GapContext(
        gapStart: Date(timeIntervalSince1970: 1_800_000_000),
        gapEnd: Date(timeIntervalSince1970: 1_800_086_400),
        kind: .transport,
        fromLocationFrom: nil,
        fromLocationTo: "Berlin",
        toLocationFrom: "Side-81907",
        toLocationTo: nil
    )
    let result = Check24DeepLinkBuilder().suggestions(for: context)
    let car = result.links.first { $0.title.contains("Mietwagen suchen") }
    let url = car?.url?.absoluteString ?? ""
    #expect(url.contains("mietwagen.check24.de/ul/jumpin"))
    #expect(url.contains("dep_destination_name=Berlin"))
    #expect(url.contains("dest_destination_name=Side"))
    #expect(!url.contains("81907"))
}

@Test("Check24DeepLinkBuilder Mietwagen: reine IATA-Hints werden übersprungen")
func deepLinkCarRentalSkipsBareIATA() {
    let iataOnly = GapContext(
        gapStart: Date(timeIntervalSince1970: 1_800_000_000),
        gapEnd: Date(timeIntervalSince1970: 1_800_086_400),
        kind: .transport,
        fromLocationFrom: "FRA",
        fromLocationTo: "MUC",
        toLocationFrom: "PMI",
        toLocationTo: "TXL"
    )
    let iataResult = Check24DeepLinkBuilder().suggestions(for: iataOnly)
    #expect(!iataResult.links.contains { $0.title.contains("Mietwagen suchen") })

    let mixed = GapContext(
        gapStart: Date(timeIntervalSince1970: 1_800_000_000),
        gapEnd: Date(timeIntervalSince1970: 1_800_086_400),
        kind: .transport,
        fromLocationFrom: nil,
        fromLocationTo: "MUC",
        toLocationFrom: nil,
        toLocationTo: "Yogyakarta"
    )
    let mixedResult = Check24DeepLinkBuilder().suggestions(for: mixed)
    let url = mixedResult.links.first { $0.title.contains("Mietwagen suchen") }?.url?.absoluteString ?? ""
    #expect(url.contains("dep_destination_name=Yogyakarta"))
    #expect(url.contains("dest_destination_name=Yogyakarta"))
    #expect(!url.contains("MUC"))
}

@Test("Check24DeepLinkBuilder Mietwagen: Stadt mit IATA in Klammern")
func deepLinkCarRentalStripsParentheticalIATA() {
    let context = GapContext(
        gapStart: Date(timeIntervalSince1970: 1_800_000_000),
        gapEnd: Date(timeIntervalSince1970: 1_800_086_400),
        kind: .transport,
        fromLocationFrom: nil,
        fromLocationTo: "Frankfurt (FRA)",
        toLocationFrom: "München (MUC)",
        toLocationTo: nil
    )
    let url = Check24DeepLinkBuilder().suggestions(for: context)
        .links.first { $0.title.contains("Mietwagen suchen") }?.url?.absoluteString ?? ""
    #expect(url.contains("dep_destination_name=Frankfurt"))
    #expect(url.contains("dest_destination_name=") && url.contains("nchen"))
    #expect(!url.contains("FRA"))
    #expect(!url.contains("MUC"))
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

@Test("ActivityListParser: rentalcar → carRental; car/ended/cancelled verworfen")
func activityListRentalcarMapsToCarRentalAndSkipsInsuranceAndPast() throws {
    let json = """
    {
      "activities": [
        {
          "startDate": "2099-06-22T08:00:00",
          "endDate": "2099-06-29T08:00:00",
          "status": { "key": "upcoming" },
          "product": { "key": "rentalcar", "label": "Mietwagen" },
          "detail": { "line1": "Mietwagen Test", "line2": "Palma de Mallorca" },
          "link": { "link": "https://mietwagen.check24.de/ul/booking/list/foreign/testrental1" },
          "foreignId": "RC-TEST-1"
        },
        {
          "startDate": "2099-01-01T00:00:00",
          "endDate": "2099-12-31T00:00:00",
          "status": { "key": "presale_priced" },
          "product": { "key": "car", "label": "Kfz-Versicherung" },
          "detail": { "line1": "Kfz" },
          "link": { "link": "https://www.check24.de/einsurance/kfz/kfzEntry.kfz" }
        },
        {
          "startDate": "2025-06-22T08:00:00",
          "endDate": "2025-06-29T08:00:00",
          "status": { "key": "ended" },
          "product": { "key": "rentalcar" },
          "detail": { "line1": "Vergangen Mietwagen" },
          "link": { "link": "https://mietwagen.check24.de/ul/booking/list/foreign/ended1" }
        },
        {
          "startDate": "2099-07-01T08:00:00",
          "endDate": "2099-07-08T08:00:00",
          "status": { "key": "cancelled" },
          "product": { "key": "rentalcar" },
          "detail": { "line1": "Storniert Mietwagen" },
          "link": { "link": "https://mietwagen.check24.de/ul/booking/list/foreign/cancel1" }
        },
        {
          "startDate": "2099-08-11T23:59:00",
          "endDate": "2099-08-14T12:00:00",
          "status": { "key": "upcoming" },
          "product": { "key": "hotel" },
          "detail": { "line1": "Hotel Regression" },
          "link": { "link": "https://hotel.check24.de/kundenbereich/buchung/11111111-1111-1111-1111-111111111111" }
        },
        {
          "startDate": "2099-09-01T10:00:00",
          "endDate": "2099-09-05T18:00:00",
          "status": { "key": "upcoming" },
          "product": { "key": "flight" },
          "detail": { "line1": "Flug Regression" },
          "link": { "link": "https://flug.check24.de/kundenbereich/TESTPNR/Name" }
        },
        {
          "startDate": "2099-08-18T23:59:00",
          "endDate": "2099-08-19T12:00:00",
          "status": { "key": "upcoming" },
          "product": { "key": "holidayflat" },
          "detail": { "line1": "Ferienwohnung Regression" },
          "link": { "link": "https://ferienwohnung.check24.de/kundenbereich/buchung/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" }
        },
        {
          "startDate": "2099-10-26T00:00:00",
          "endDate": "2099-11-02T00:00:00",
          "status": { "key": "upcoming" },
          "product": { "key": "package" },
          "detail": { "line1": "Pauschalreise Regression" },
          "link": { "link": "https://urlaub.check24.de/kundenbereich/detail/packagetest1" }
        }
      ]
    }
    """

    let parsed = try ActivityListParser().parseActivityListHTML(json)
    #expect(parsed.bookings.count == 5)

    let rental = try #require(parsed.bookings.first { $0.type == .carRental })
    #expect(rental.title == "Mietwagen Test")
    #expect(rental.externalUrl == "https://mietwagen.check24.de/ul/booking/list/foreign/testrental1")
    #expect(rental.confirmationCode == "RC-TEST-1")
    #expect(rental.locationTo == "Palma de Mallorca")

    #expect(parsed.bookings.contains { $0.type == .hotel && $0.title == "Hotel Regression" })
    #expect(parsed.bookings.contains { $0.type == .flight && $0.title == "Flug Regression" })
    #expect(parsed.bookings.contains { $0.type == .hotel && $0.title == "Ferienwohnung Regression" })
    #expect(parsed.bookings.contains { $0.type == .hotel && $0.title == "Pauschalreise Regression" })
    #expect(!parsed.bookings.contains { $0.title == "Kfz" })
    #expect(!parsed.bookings.contains { $0.title == "Vergangen Mietwagen" })
    #expect(!parsed.bookings.contains { $0.title == "Storniert Mietwagen" })
}

@Test("ActivityListParser mapBookingType: rentalcar → carRental")
func activityListMapBookingTypeRentalcar() {
    let parser = ActivityListParser()
    #expect(parser.mapBookingType("rentalcar") == .carRental)
    #expect(parser.mapBookingType("car") == .other)
    #expect(parser.mapBookingType("hotel") == .hotel)
}

@Test("ActivityListParser HTML-Fallback: mietwagen-Link → carRental")
func activityListHTMLFallbackMietwagenIsCarRental() throws {
    let html = """
    <html><body>
    <a href="https://mietwagen.check24.de/ul/booking/list/foreign/testrental1">Mietwagen Test</a>
    22.06.2099 – 29.06.2099
    </body></html>
    """
    let parsed = try ActivityListParser().parseActivityListHTML(html)
    #expect(parsed.bookings.count == 1)
    #expect(parsed.bookings[0].type == .carRental)
    #expect(parsed.bookings[0].externalUrl == "https://mietwagen.check24.de/ul/booking/list/foreign/testrental1")
}

@Test("ActivityListParser normalizeBookingDetailURL: Mietwagen-URL unverändert")
func activityListNormalizeLeavesCarRentalURLUntouched() {
    let parser = ActivityListParser()
    let rental = "https://mietwagen.check24.de/ul/booking/list/foreign/testrental1"
    #expect(parser.normalizeBookingDetailURL(rental) == rental)
    #expect(parser.normalizeBookingDetailURL("\(rental)?foo=1") == rental)

    let hotelUUID = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    #expect(
        parser.normalizeBookingDetailURL(
            "https://m.hotel.check24.de/ul/kundenbereich/buchung/\(hotelUUID)?x=1"
        ) == "https://hotel.check24.de/kundenbereich/buchung/\(hotelUUID)"
    )
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
