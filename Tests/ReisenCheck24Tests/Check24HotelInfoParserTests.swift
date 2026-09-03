import Testing
import Foundation
@testable import ReisenCheck24
import ReisenDomain

@Test("Check24HotelInfoParser: hotelInfo cityStreet/zip/city/country → locationToAddress")
func check24HotelInfoParserMapsHotelInfoAddress() throws {
    let html = """
    <html><body>
    window.__STATE__ = {
      "accountOwnerStreet": "Tölzer Str. 1",
      "billingAddress": {"street": "Invoice Weg 9", "zipcode": "12345", "city": "München"},
      "hotelInfo": {
        "displayName": "Example Hotel Singapore",
        "cityStreet": "201 Balestier Road",
        "zip": "329926",
        "cityName": "Singapore",
        "countryName": "SG",
        "fullCountryNameGerman": "Singapur"
      }
    };
    </body></html>
    """
    let parsed = try #require(Check24HotelInfoParser.parse(from: html))
    #expect(parsed.locationTo == "Singapore")
    #expect(parsed.locationToAddress == PostalAddress.lines(
        street: "201 Balestier Road",
        postalCode: "329926",
        city: "Singapore",
        country: "Singapur"
    ))
}

@Test("Check24HotelInfoParser: ohne hotelInfo bleibt leer")
func check24HotelInfoParserMissingHotelInfoReturnsNil() {
    #expect(Check24HotelInfoParser.parse(from: "<html>accountOwnerStreet</html>") == nil)
}

@Test("Check24HotelInfoParser: Billing-Straße allein ist keine Hoteladresse")
func check24HotelInfoParserIgnoresBillingStreet() {
    let html = """
    {"accountOwnerStreet":"Tölzer Str. 1","street":"Invoice Weg 9","zipcode":"12345"}
    """
    #expect(Check24HotelInfoParser.parse(from: html) == nil)
}

@Test("mapDraft: hotelInfo-Adresse aus Hotel-Detail füllt leeren Katalog")
@MainActor
func check24MapDraftUsesHotelInfoAddressFromStay() throws {
    let start = Date(timeIntervalSinceNow: 86_400 * 30)
    let end = Date(timeIntervalSinceNow: 86_400 * 33)
    let url = "https://hotel.check24.de/kundenbereich/buchung/019e73fc-1937-7210-8959-820e50d66410"
    let parsed = ParsedBooking(
        type: .hotel,
        title: "Example Hotel",
        confirmationCode: "ABC",
        externalUrl: url,
        startAt: start,
        endAt: end,
        locationTo: "Singapore",
        locationToAddress: nil
    )
    let address = PostalAddress.lines(
        street: "201 Balestier Road",
        postalCode: "329926",
        city: "Singapore",
        country: "Singapur"
    )
    let stay = HotelCheckInOut(
        checkInMinutes: 14 * 60,
        checkOutMinutes: 12 * 60,
        locationTo: "Singapore",
        locationToAddress: address
    )
    let draft = try #require(
        Check24TravelProvider().mapDraft(
            parsed,
            allBookings: [parsed],
            deadlinesByBookingURL: [:],
            hotelStayByBookingURL: [url: stay],
            guestHintsByBookingURL: [:],
            bookingDetailsByBookingKey: [:]
        )
    )
    #expect(draft.locationTo == "Singapore")
    #expect(draft.locationToAddress == address)
}

@Test("makeBasketDrafts: hotelInfo-Adresse füllt Mehrzimmer-Katalog ohne PSD-Straße")
@MainActor
func check24BasketDraftsUseHotelInfoAddressFromStay() throws {
    let uuid = "019e73fc-1937-7210-8959-820e50d66410"
    let url = "https://hotel.check24.de/kundenbereich/buchung/\(uuid)"
    let start = Date(timeIntervalSinceNow: 86_400 * 30)
    let end = Date(timeIntervalSinceNow: 86_400 * 33)
    let parsed = ParsedBooking(
        type: .hotel,
        title: "Example Hotel",
        confirmationCode: "ABC",
        externalUrl: url,
        startAt: start,
        endAt: end,
        locationTo: "Singapore",
        locationToAddress: nil,
        statusRaw: "upcoming"
    )
    let address = PostalAddress.lines(
        street: "201 Balestier Road",
        postalCode: "329926",
        city: "Singapore",
        country: "Singapur"
    )
    let stay = HotelCheckInOut(
        checkInMinutes: 14 * 60,
        checkOutMinutes: 12 * 60,
        locationTo: "Singapore",
        locationToAddress: address
    )
    let basket = HotelBasketParser.ParsedHotelBasket(
        basketId: "basket-1",
        basketPriceEffectiveAmount: 100,
        basketPriceCurrency: "EUR",
        items: [
            HotelBasketParser.ParsedHotelBasketItem(
                bookingUuid: uuid,
                bookingNumber: "ABC",
                roomCategoryTitle: "Doppelzimmer",
                priceTotalAmount: 100,
                priceTotalCurrency: "EUR",
                guestSummary: nil,
                sortIndex: 0
            )
        ]
    )
    let drafts = Check24TravelProvider().makeBasketDrafts(
        basketsByBasketId: ["basket-1": basket],
        canonicalBookingUuidByBasketId: ["basket-1": uuid],
        parsedBookingByBookingUuid: [uuid: parsed],
        deadlinesByBasketId: [:],
        deadlinesByBookingURL: [:],
        hotelStayByBasketId: ["basket-1": stay],
        hotelStayByBookingURL: [:],
        guestHintsByBasketId: [:],
        guestHintsByBookingURL: [:],
        bookingDetailsByBasketId: [:],
        bookingDetailsByBookingKey: [:]
    )
    let draft = try #require(drafts[url])
    #expect(draft.locationTo == "Singapore")
    #expect(draft.locationToAddress == address)
}
