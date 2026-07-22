import Testing
import Foundation
import ReisenCheck24
import ReisenDomain

@Test("ActivityListParser liest payment.amount und Zimmeranzahl aus Activities-JSON")
func activityListParsesPaymentAndRoomCount() throws {
    let json = """
    {
      "activities": [
        {
          "startDate": "2026-08-11T23:59:00",
          "endDate": "2026-08-14T12:00:00",
          "status": { "key": "upcoming" },
          "product": { "key": "hotel" },
          "detail": { "line1": "Mimpi Resort Menjangan" },
          "foreignId": "room-a",
          "payment": { "amount": 203.83, "suffix": "€" },
          "productSpecificData": {
            "hotel_name": "Mimpi Resort Menjangan",
            "sso_room_text": "1 Doppelzimmer mit Terrasse"
          },
          "link": { "link": "https://hotel.check24.de/kundenbereich/buchung/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" }
        }
      ]
    }
    """

    let parsed = try ActivityListParser().parseActivityListHTML(json)
    let booking = try #require(parsed.bookings.first)
    #expect(booking.catalogPriceAmount == 203.83)
    #expect(booking.catalogPriceCurrency == "EUR")
    #expect(booking.catalogRoomCount == 1)
    #expect(booking.catalogRoomCategory == "Doppelzimmer mit Terrasse")
}

@Test("BookingDetailsParser summiert mehrere Zimmer auf einer Detailseite")
func bookingDetailsSumsMultipleRoomsOnPage() {
    let html = """
    <div class="a48418653-roomTitle">1x Bungalow</div>
    <div class="a48418653-roomTitle">1x Grand-Bungalow, 1 Queen-Bett</div>
    <span>effektiver Preis: 840,94 €</span>
    """
    let details = BookingDetailsParser().parse(from: html, bookingType: .hotel)
    #expect(details.totalPriceAmount == 840.94)
    #expect(details.roomCount == 2)
}

@Test("Mehrere Zimmer-Activities: Katalogpreis je Zimmer, nicht Bestell-Gesamtpreis")
func multiRoomSiblingActivitiesKeepCatalogPrice() {
    let start = Date(timeIntervalSince1970: 1_786_500_000)
    let end = Date(timeIntervalSince1970: 1_786_600_000)

    let roomA = ParsedBooking(
        type: .hotel,
        title: "Mimpi Resort Menjangan",
        confirmationCode: "room-a",
        externalUrl: "https://hotel.check24.de/kundenbereich/buchung/a",
        startAt: start,
        endAt: end,
        status: .confirmed,
        catalogPriceAmount: 203.83,
        catalogPriceCurrency: "EUR",
        catalogRoomCount: 1,
        catalogRoomCategory: "Doppelzimmer mit Terrasse"
    )
    let roomB = ParsedBooking(
        type: .hotel,
        title: "Mimpi Resort Menjangan",
        confirmationCode: "room-b",
        externalUrl: "https://hotel.check24.de/kundenbereich/buchung/b",
        startAt: start,
        endAt: end,
        status: .confirmed,
        catalogPriceAmount: 235.0,
        catalogPriceCurrency: "EUR",
        catalogRoomCount: 1,
        catalogRoomCategory: "Sonstige Zimmerkategorie"
    )

    let orderTotal = ParsedBookingDetails(
        rawDetailsFingerprint: "order",
        totalPriceAmount: 448.83,
        totalPriceCurrency: "EUR",
        roomCount: 2
    )

    let resolvedA = HotelBookingPriceResolver.resolve(
        booking: roomA,
        siblings: [roomA, roomB],
        detail: orderTotal
    )
    let resolvedB = HotelBookingPriceResolver.resolve(
        booking: roomB,
        siblings: [roomA, roomB],
        detail: orderTotal
    )

    #expect(resolvedA?.totalPriceAmount == 203.83)
    #expect(resolvedA?.roomCount == 1)
    #expect(resolvedB?.totalPriceAmount == 235.0)
    #expect(resolvedB?.roomCount == 1)
}

@Test("Eine Activity mit Mehrzimmer-Detailseite: Bestell-Gesamtpreis und Zimmeranzahl")
func singleActivityMultiRoomDetailUsesOrderTotal() {
    let start = Date(timeIntervalSince1970: 1_786_500_000)
    let end = Date(timeIntervalSince1970: 1_786_600_000)

    let booking = ParsedBooking(
        type: .hotel,
        title: "Taman Sari Bali Resort & Spa",
        confirmationCode: "one",
        externalUrl: "https://hotel.check24.de/kundenbereich/buchung/t",
        startAt: start,
        endAt: end,
        status: .confirmed,
        catalogPriceAmount: 239.4,
        catalogPriceCurrency: "EUR",
        catalogRoomCount: 1,
        catalogRoomCategory: "Bungalow"
    )

    let orderTotal = ParsedBookingDetails(
        rawDetailsFingerprint: "order",
        totalPriceAmount: 840.94,
        totalPriceCurrency: "EUR",
        roomCategory: "Bungalow",
        roomCount: 2
    )

    let resolved = HotelBookingPriceResolver.resolve(
        booking: booking,
        siblings: [booking],
        detail: orderTotal
    )

    #expect(resolved?.totalPriceAmount == 840.94)
    #expect(resolved?.roomCount == 2)
}
