import Foundation

/// Decodable shape of Check24 `basketDetails` embedded in hotel detail HTML.
struct HotelBasketDetailsDTO: Decodable {
    struct PriceDTO: Decodable {
        let amount: Double?
        let currency: String?
        let effectiveAmount: Double?
        let effectiveCurrency: String?
    }

    struct GuestDTO: Decodable {
        let firstName: String?
        let lastName: String?
    }

    struct RoomDTO: Decodable {
        let categoryTitle: String?
        let guests: [GuestDTO]?
    }

    struct PriceTotalDTO: Decodable {
        let amount: Double?
        let currency: String?
        let effectiveAmount: Double?
        let effectiveCurrency: String?
    }

    struct ItemDTO: Decodable {
        let bookingUuid: String
        let bookingNumber: String?
        let room: RoomDTO?
        let rooms: [RoomDTO]?
        let priceTotal: PriceTotalDTO?
    }

    let basketId: String
    let basketPrice: PriceDTO?
    let items: [ItemDTO]?
}
