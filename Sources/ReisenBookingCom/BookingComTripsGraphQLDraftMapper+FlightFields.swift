import Foundation
import ReisenDomain

extension BookingComTripsGraphQLParser {
    func applyFlightMappedFields(
        _ reservation: GraphQLReservation,
        into fields: inout MappedFields,
        tripTitle: String?
    ) {
        let route = flightRoute(reservation.flightComponents)
        fields.locationFrom = route.fromLabel
        fields.locationTo = route.toLabel
        if let fromCity = route.fromCity, let toCity = route.toCity {
            fields.title = "\(fromCity) → \(toCity)"
        } else {
            fields.title = tripTitle
        }
        fields.confirmationCode = BookingComParsing.nonEmpty(reservation.identifiers?.publicFacingIdentifier)
            ?? reservation.identifiers?.publicId
        fields.airline = route.airline
        fields.passengerCount = reservation.passengerCount
        fields.flightDepartureOffsetSeconds = BookingComParsing.offsetSeconds(from: reservation.startDateTime)
        fields.flightArrivalOffsetSeconds = BookingComParsing.offsetSeconds(from: reservation.endDateTime)
    }
}
