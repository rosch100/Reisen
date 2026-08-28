import Foundation

/// DTOs für `window.c24mw.globals.CpInitial` auf der Mietwagen-Detailseite.
struct Check24CarRentalCpInitialDTO: Decodable {
    let bookingNumber: String?
    let rentalcarDetails: Details?
    let stations: [Station]?
    let vehicleHandovers: Handovers?
    let cancel: Cancel?
    let actions: [Action]?

    enum CodingKeys: String, CodingKey {
        case bookingNumber = "booking_number"
        case rentalcarDetails
        case stations
        case vehicleHandovers
        case cancel
        case actions
    }

    struct Details: Decodable {
        let categoryName: String?
        let description: String?
        let price: String?
        let isGuaranteedCarModel: Bool?

        enum CodingKeys: String, CodingKey {
            case categoryName = "category_name"
            case description
            case price
            case isGuaranteedCarModel
        }
    }

    struct Station: Decodable {
        let street: String?
        let zipCity: String?
        let text: String?

        enum CodingKeys: String, CodingKey {
            case street
            case zipCity = "zip_city"
            case text
        }
    }

    struct Handovers: Decodable {
        let isOneWay: Bool?
        let pickup: HandoverPoint?
        let dropoff: HandoverPoint?
    }

    struct HandoverPoint: Decodable {
        let name: String?
        let address: String?
    }

    struct Cancel: Decodable {
        let supplier: String?
    }

    struct Action: Decodable {
        let title: String?
        let href: String?
    }
}
