import Foundation

extension HotelBasketParser {
    /// Flatten: in manchen Check24-Darstellungen stecken mehrere Zimmer in `items[...].rooms[]`.
    static func mapItems(from itemsDTO: [HotelBasketDetailsDTO.ItemDTO]) -> [ParsedHotelBasketItem] {
        itemsDTO.enumerated().flatMap { itemIndex, item in
            mapItemRooms(item: item, itemIndex: itemIndex)
        }
    }
}
