import Foundation

struct AirbnbStayReservation: Decodable {
    let confirmationCode: String?
    let status: String?
    let guestCountDetails: GuestCountDetails?
    let supplyListing: AirbnbSupplyListing?
}

struct AirbnbActivityReservation: Decodable {
    let confirmationCode: String?
    let status: String?
    let guestCountDetails: GuestCountDetails?
}

struct GuestCountDetails: Decodable {
    let numberOfAdults: Int?
}

struct AirbnbSupplyListing: Decodable {
    let roomsAndSpaces: RoomsAndSpaces?
}

struct RoomsAndSpaces: Decodable {
    let numberOfBedrooms: Int?
}
