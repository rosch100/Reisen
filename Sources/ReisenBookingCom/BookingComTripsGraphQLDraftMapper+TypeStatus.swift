import Foundation
import ReisenDomain

extension BookingComTripsGraphQLParser {
    func bookingType(of reservation: GraphQLReservation) -> BookingType {
        let typeName = reservation.typeName ?? ""
        if typeName.contains("Flight") || reservation.verticalType == "FLIGHT" {
            return .flight
        }
        if typeName.contains("Accommodation") || reservation.verticalType == "ACCOMMODATION" {
            return .hotel
        }
        return .other
    }

    func status(from raw: String?) -> BookingStatus {
        switch raw?.uppercased() {
        case "CONFIRMED":
            return .confirmed
        case "CANCELLED", "CANCELED":
            return .cancelled
        default:
            return .unknown
        }
    }
}
