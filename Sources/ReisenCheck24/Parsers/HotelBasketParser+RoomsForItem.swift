import Foundation

extension HotelBasketParser {
    static func roomsForItem(_ item: HotelBasketDetailsDTO.ItemDTO) -> [HotelBasketDetailsDTO.RoomDTO] {
        if let rooms = item.rooms, !rooms.isEmpty { return rooms }
        if let room = item.room { return [room] }
        return []
    }
}
