import Foundation
import ReisenDomain

extension BookingComTripsGraphQLParser {
    func bookingType(of reservation: GraphQLReservation) -> BookingType {
        if matches(reservation, .containing("Flight"), vertical: "FLIGHT") {
            return .flight
        }
        if matches(reservation, .containing("Accommodation"), vertical: "ACCOMMODATION") {
            return .hotel
        }
        if matches(reservation, .exact("AttractionReservation"), vertical: "ATTRACTION") {
            return .activity
        }
        if matches(reservation, .exact("CarReservation"), vertical: "CAR") {
            return .carRental
        }
        return .other
    }

    func isPrebookTaxi(_ reservation: GraphQLReservation) -> Bool {
        matches(reservation, .exact("PrebookTaxiReservation"), vertical: "PREBOOK_TAXI")
    }

    func publicConfirmationCode(
        _ reservation: GraphQLReservation,
        preferring preferred: String? = nil
    ) -> String? {
        NonEmpty.string(preferred)
            ?? NonEmpty.string(reservation.identifiers?.publicFacingIdentifier)
            ?? NonEmpty.string(reservation.identifiers?.publicId)
    }

    private enum TypeNameMatch {
        case exact(String)
        case containing(String)
    }

    private func matches(
        _ reservation: GraphQLReservation,
        _ typeName: TypeNameMatch,
        vertical: String
    ) -> Bool {
        let typeHit: Bool
        switch typeName {
        case .exact(let name):
            typeHit = reservation.typeName == name
        case .containing(let part):
            typeHit = (reservation.typeName ?? "").contains(part)
        }
        return typeHit || reservation.verticalType == vertical
    }
}
