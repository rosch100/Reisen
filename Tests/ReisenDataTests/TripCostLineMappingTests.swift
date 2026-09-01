import Foundation
import Testing
import SwiftData
import ReisenData
import ReisenDomain

@MainActor
@Test func tripCostLineMapping_unpairedRateDetails_countAsMissing() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext

    func booking(title: String, amount: Double?, currency: String?) -> SDBooking {
        let model = SDBooking(
            providerRaw: ProviderID.manual.rawValue,
            bookingTypeRaw: BookingType.hotel.rawValue,
            title: title,
            startAt: Date(timeIntervalSince1970: 1),
            endAt: Date(timeIntervalSince1970: 2),
            statusRaw: BookingStatus.confirmed.rawValue
        )
        if amount != nil || currency != nil {
            model.rateDetails = SDBookingRateDetails(
                totalPriceAmount: amount,
                totalPriceCurrency: currency
            )
        }
        context.insert(model)
        return model
    }

    let priced = booking(title: "Priced", amount: 40, currency: "EUR")
    let amountOnly = booking(title: "AmountOnly", amount: 10, currency: nil)
    let currencyOnly = booking(title: "CurrencyOnly", amount: nil, currency: "USD")

    let gap = SDGap(
        gapStart: Date(timeIntervalSince1970: 7),
        gapEnd: Date(timeIntervalSince1970: 8),
        kindRaw: "other",
        priceAmount: 5,
        priceCurrencyCode: "USD"
    )
    context.insert(gap)

    let summary = TripCostLineMapping.summary(
        bookings: [priced, amountOnly, currencyOnly],
        gaps: [gap]
    )
    #expect(summary.totalsByCurrency["EUR"] == 40)
    #expect(summary.totalsByCurrency["USD"] == 5)
    #expect(summary.pricedCount == 2)
    #expect(summary.missingCount == 2)
}
