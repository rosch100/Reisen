import Testing
import Foundation
import ReisenCheck24
import ReisenDomain

@Test("ActivityListParser schließt stornierte und vergangene Buchungen aus")
func activityListExcludesCancelledAndPast() throws {
    let json = """
    {
      "activities": [
        {
          "startDate": "2026-08-11T23:59:00",
          "endDate": "2026-08-14T12:00:00",
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
