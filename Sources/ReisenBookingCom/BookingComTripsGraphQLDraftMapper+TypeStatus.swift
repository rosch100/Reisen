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
}
