import Foundation

extension HotelBasketParser {
    static func mapItemRooms(
        item: HotelBasketDetailsDTO.ItemDTO,
        itemIndex: Int
    ) -> [ParsedHotelBasketItem] {
        let rooms = roomsForItem(item)
        guard !rooms.isEmpty else { return [ParsedHotelBasketItem]() }

        // Kein „Preis raten“: Wenn `priceTotal` mehrere Zimmer umfasst (rooms.count > 1),
        // lassen wir die Einzel-Preisfelder nil.
        let price = item.priceTotal
        let amount = (rooms.count == 1) ? (price?.effectiveAmount ?? price?.amount) : nil
        let currency = (rooms.count == 1) ? (price?.effectiveCurrency ?? price?.currency) : nil

        return rooms.enumerated().map { roomIndex, room in
            ParsedHotelBasketItem(
                bookingUuid: item.bookingUuid,
                bookingNumber: item.bookingNumber,
                roomCategoryTitle: room.categoryTitle,
                priceTotalAmount: amount,
                priceTotalCurrency: currency,
                guestSummary: guestSummary(from: room),
                sortIndex: itemIndex * 10_000 + roomIndex
            )
        }
    }
}
