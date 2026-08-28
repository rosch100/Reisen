import Foundation
import ReisenDomain

extension Check24TravelProvider {
    func mapBasketRateDetails(
        basket: HotelBasketParser.ParsedHotelBasket,
        details: ParsedBookingDetails?
    ) -> BookingRateDetails? {
        let roomItems = basket.items.map { item in
            BookingRoomItem(
                category: item.roomCategoryTitle,
                confirmationCode: item.bookingNumber,
                priceAmount: item.priceTotalAmount,
                priceCurrency: item.priceTotalCurrency,
                guestSummary: item.guestSummary,
                sortIndex: item.sortIndex
            )
        }

        guard !roomItems.isEmpty else { return nil }

        let uniqueCategories: [String] = {
            var seen = Set<String>()
            var ordered: [String] = []
            for item in roomItems {
                guard let cat = item.category?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !cat.isEmpty,
                      seen.insert(cat).inserted
                else { continue }
                ordered.append(cat)
            }
            return ordered
        }()

        let roomCount = basket.items.count
        let basketRate = BookingRateDetails(
            totalPriceAmount: basket.basketPriceEffectiveAmount,
            totalPriceCurrency: basket.basketPriceCurrency,
            roomCategory: uniqueCategories.joined(separator: " + "),
            roomCount: roomCount,
            roomItems: roomItems,
            lastParsedAt: Date()
        )
        return BookingRateDetails.merging(existing: details?.asRateDetails(), incoming: basketRate)
    }
}
