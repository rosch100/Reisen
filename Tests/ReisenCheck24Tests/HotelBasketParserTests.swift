import Testing
import Foundation
@testable import ReisenCheck24

@Test("HotelBasketParser parst basketDetails (Multi-Room Basket)") func hotelBasketParserParsesBasketDetails() {
    let html = """
    <html>
      <body>
        window.__STATE__ = {
          "basketDetails":{
            "basketId":"019f76d2-47c7-71db-9636-02e155e19e46",
            "basketPrice":{
              "amount":242.94,
              "currency":"EUR",
              "effectiveAmount":232.94,
              "effectiveCurrency":"EUR"
            },
            "items":[
              {
                "bookingUuid":"019f76d2-4832-7146-9e34-317f3131fca6",
                "bookingNumber":"i22154533t",
                "room":{
                  "categoryTitle":"Superior Doppel- oder Zweibettzimmer",
                  "guests":[{"firstName":"Roland","lastName":"Schramme"}]
                },
                "priceTotal":{
                  "amount":114,
                  "currency":"EUR",
                  "effectiveAmount":109,
                  "effectiveCurrency":"EUR"
                }
              },
              {
                "bookingUuid":"019f76d2-4f30-711b-8e6b-d332e5ce987d",
                "bookingNumber":"1128149373567478",
                "room":{
                  "categoryTitle":"Deluxe Doppel-/Zweibettzimmer",
                  "guests":[{"firstName":"Danila","lastName":"Liebe"}]
                },
                "priceTotal":{
                  "amount":128.94,
                  "currency":"EUR",
                  "effectiveAmount":123.94,
                  "effectiveCurrency":"EUR"
                }
              }
            ]
          }
        };
      </body>
    </html>
    """

    let basket = HotelBasketParser.parse(from: html)
    #expect(basket != nil)

    #expect(basket?.basketId == "019f76d2-47c7-71db-9636-02e155e19e46")
    #expect(basket?.basketPriceEffectiveAmount == 232.94)
    #expect(basket?.basketPriceCurrency == "EUR")
    #expect(basket?.items.count == 2)

    let bookingNumbers = basket?.items.compactMap(\.bookingNumber) ?? []
    #expect(bookingNumbers.contains("i22154533t"))
    #expect(bookingNumbers.contains("1128149373567478"))

    let categories = basket?.items.compactMap(\.roomCategoryTitle) ?? []
    #expect(categories.contains("Superior Doppel- oder Zweibettzimmer"))
    #expect(categories.contains("Deluxe Doppel-/Zweibettzimmer"))
}

@Test("HotelBasketParser flacht items[0].rooms[] zu mehreren Positions-Items") func hotelBasketParserFlattensRoomsArray() throws {
    let html = """
    <html>
      <body>
        window.__STATE__ = {
          "basketDetails":{
            "basketId":"basket-1",
            "basketPrice":{
              "amount":242.94,
              "currency":"EUR",
              "effectiveAmount":232.94,
              "effectiveCurrency":"EUR"
            },
            "items":[
              {
                "bookingUuid":"booking-uuid-same",
                "bookingNumber":"664105651",
                "room":{
                  "categoryTitle":"Standard Doppelzimmer",
                  "guests":[{"firstName":"Roland","lastName":"Schramme"}]
                },
                "rooms":[
                  {
                    "categoryTitle":"Standard Doppelzimmer",
                    "guests":[{"firstName":"Roland","lastName":"Schramme"}]
                  },
                  {
                    "categoryTitle":"Standard Doppelzimmer",
                    "guests":[{"firstName":"Danila","lastName":"Liebe"}]
                  }
                ],
                "priceTotal":{
                  "amount":123.94,
                  "currency":"EUR",
                  "effectiveAmount":123.94,
                  "effectiveCurrency":"EUR"
                }
              }
            ]
          }
        };
      </body>
    </html>
    """

    let basket = try #require(HotelBasketParser.parse(from: html))
    #expect(basket.items.count == 2)
    #expect(basket.items[0].guestSummary == "Roland Schramme")
    #expect(basket.items[1].guestSummary == "Danila Liebe")
}

@Test("HotelBasketParser kanonisiert Platzhalter-Gäste als 'weitere Gäste'") func hotelBasketParserCanonicalizesPlaceholderGuests() throws {
    let html = """
    <html>
      <body>
        window.__STATE__ = {
          "basketDetails":{
            "basketId":"basket-2",
            "basketPrice":{"amount":100.0,"currency":"EUR","effectiveAmount":100.0,"effectiveCurrency":"EUR"},
            "items":[
              {
                "bookingUuid":"booking-uuid",
                "bookingNumber":"n",
                "rooms":[
                  {
                    "categoryTitle":"Standard Doppelzimmer",
                    "guests":[
                      {"firstName":"Roland","lastName":"Schramme"},
                      {"firstName":"-","lastName":"-"},
                      {"firstName":"-","lastName":"-"}
                    ]
                  }
                ],
                "priceTotal":{
                  "amount":100.0,
                  "currency":"EUR",
                  "effectiveAmount":100.0,
                  "effectiveCurrency":"EUR"
                }
              }
            ]
          }
        };
      </body>
    </html>
    """

    let basket = try #require(HotelBasketParser.parse(from: html))
    #expect(basket.items.count == 1)
    #expect(basket.items[0].guestSummary == "Roland Schramme und 2 weitere Gäste")
}

@MainActor
@Test("Check24 mapBasketRateDetails bildet total + roomItems ab") func check24MapBasketRateDetailsBuildsRooms() {
    let provider = Check24TravelProvider()

    let basket = HotelBasketParser.ParsedHotelBasket(
        basketId: "basket-1",
        basketPriceEffectiveAmount: 232.94,
        basketPriceCurrency: "EUR",
        items: [
            .init(
                bookingUuid: "room-uuid-1",
                bookingNumber: "n1",
                roomCategoryTitle: "Superior Zimmer",
                priceTotalAmount: 109,
                priceTotalCurrency: "EUR",
                guestSummary: "Roland Schramme",
                sortIndex: 0
            ),
            .init(
                bookingUuid: "room-uuid-2",
                bookingNumber: "n2",
                roomCategoryTitle: "Deluxe Zimmer",
                priceTotalAmount: 123.94,
                priceTotalCurrency: "EUR",
                guestSummary: nil,
                sortIndex: 1
            )
        ]
    )

    let details = ParsedBookingDetails(
        rawDetailsFingerprint: "fp",
        totalPriceAmount: nil,
        totalPriceCurrency: nil,
        roomCategory: nil,
        boardTypeRaw: nil,
        includedBreakfast: nil,
        guestCount: nil,
        roomCount: 2,
        airline: nil,
        passengerCount: nil,
        baggageInfoRaw: nil
    )

    let rate = provider.mapBasketRateDetails(basket: basket, details: details)
    #expect(rate?.totalPriceAmount == 232.94)
    #expect(rate?.totalPriceCurrency == "EUR")
    #expect(rate?.roomCount == 2)
    #expect(rate?.roomItems.count == 2)
    #expect(rate?.roomItems[0].category == "Superior Zimmer")
    #expect(rate?.roomItems[0].confirmationCode == "n1")
    #expect(rate?.roomItems[1].category == "Deluxe Zimmer")
    #expect(rate?.roomItems[1].priceAmount == 123.94)
    #expect(rate?.roomCategory == "Superior Zimmer + Deluxe Zimmer")
}

