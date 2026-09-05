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
        "fullCountryNameGerman": "Singapur",
        "checkInCheckOut": {
          "checkInFrom": "14:00",
          "checkOutTo": "11:00"
        }
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
    #expect(parsed.checkInMinutes == 14 * 60)
    #expect(parsed.checkOutMinutes == 11 * 60)
}

@Test("Check24HotelInfoParser: ohne hotelInfo bleibt leer")
func check24HotelInfoParserMissingHotelInfoReturnsNil() {
    #expect(Check24HotelInfoParser.parse(from: "<html>accountOwnerStreet</html>") == nil)
}

@Test("Check24HotelInfoParser: kaputtes hotelInfo-JSON bleibt soft nil")
func check24HotelInfoParserCorruptJSONReturnsNil() {
    let html = #"<html>"hotelInfo": { not-json }</html>"#
    #expect(Check24HotelInfoParser.parse(from: html) == nil)
}

@Test("Check24HotelInfoParser: Billing-Straße allein ist keine Hoteladresse")
func check24HotelInfoParserIgnoresBillingStreet() {
    let html = """
    {"accountOwnerStreet":"Tölzer Str. 1","street":"Invoice Weg 9","zipcode":"12345"}
    """
    #expect(Check24HotelInfoParser.parse(from: html) == nil)
}

@Test("HotelCheckInOut.merging: JSON-Zeiten überschreiben HTML-Regex")
func hotelCheckInOutMergingPrefersHotelInfoTimes() {
    let htmlTimes = HotelCheckInOut(checkInMinutes: 15 * 60, checkOutMinutes: 10 * 60)
    let place = ParsedHotelInfo(
        locationTo: "Berlin",
        locationToAddress: nil,
        checkInMinutes: 14 * 60,
        checkOutMinutes: 11 * 60
    )
    let merged = htmlTimes.merging(place: place)
    #expect(merged.checkInMinutes == 14 * 60)
    #expect(merged.checkOutMinutes == 11 * 60)
    #expect(merged.locationTo == "Berlin")
}

@Test("Check24HotelOfferFactsParser: mealType/categoryTitle aus Rate-JSON")
func check24HotelOfferFactsParserMapsMealAndCategory() {
    let html = """
    {"effectiveFormatted":"39,32\\u00a0\\u20ac","room":{"categoryTitle":"Kapsel mit Kingsize-Bett"},
    "mealType":"none","mealTypeLabel":"ohne Verpflegung"}
    """
    let facts = Check24HotelOfferFactsParser.parse(from: html)
    #expect(facts.boardTypeRaw == BookingBoardType.roomOnly.rawValue)
    #expect(facts.includedBreakfast == false)
    #expect(facts.roomCategory == "Kapsel mit Kingsize-Bett")
}

@Test("BookingDetailsParser: Offer-JSON füllt boardType und roomCategory-Fallback")
func bookingDetailsParserFillsBoardAndCategoryFromOfferJSON() {
    let html = """
    <html>Gesamtpreis 39,32 €
    {"room":{"categoryTitle":"Kapsel mit Kingsize-Bett und Gemeinschaftsbad"},
    "mealType":"none","mealTypeLabel":"ohne Verpflegung"}
    </html>
    """
    let details = BookingDetailsParser().parse(from: html, bookingType: .hotel)
    #expect(details.boardTypeRaw == BookingBoardType.roomOnly.rawValue)
    #expect(details.includedBreakfast == false)
    #expect(details.roomCategory == "Kapsel mit Kingsize-Bett und Gemeinschaftsbad")
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
        locationTo: "Singapore · long catalog line2",
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

@Test("mapDraft: hotelInfo-Ort/Adresse haben Vorrang vor Katalog-line2")
@MainActor
func check24MapDraftPrefersHotelInfoPlaceOverCatalogLine2() throws {
    let start = Date(timeIntervalSinceNow: 86_400 * 30)
    let end = Date(timeIntervalSinceNow: 86_400 * 33)
    let url = "https://hotel.check24.de/kundenbereich/buchung/01a0531c-0906-70d5-909c-93f93d8afe10"
    let parsed = ParsedBooking(
        type: .hotel,
        title: "Hostel",
        confirmationCode: "XYZ",
        externalUrl: url,
        startAt: start,
        endAt: end,
        locationTo: "Berlin · Deutschland · Hostel-Katalogzeile",
        locationToAddress: nil
    )
    let address = PostalAddress.lines(
        street: "Johannisstr. 11",
        postalCode: "10117",
        city: "Berlin",
        country: "Deutschland"
    )
    let stay = HotelCheckInOut(
        checkInMinutes: 14 * 60,
        checkOutMinutes: 11 * 60,
        locationTo: "Berlin",
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
    #expect(draft.locationTo == "Berlin")
    #expect(draft.locationToAddress == address)
}

@Test("Hotel-Detail-Wait verlangt hotelInfo und (cityStreet oder checkInCheckOut)")
func check24HotelInfoAddressPayloadConditionRequiresStreetKeys() {
    let condition = Check24HotelInfoParser.domAddressPayloadCondition
    #expect(condition.contains("\"hotelInfo\""))
    #expect(condition.contains("\"cityStreet\""))
    #expect(condition.contains("\"checkInCheckOut\""))
    #expect(condition.contains("||"))
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
