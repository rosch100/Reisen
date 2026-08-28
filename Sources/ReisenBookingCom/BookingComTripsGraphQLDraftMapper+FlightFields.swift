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
        fields.title = PlaceLabel.route(from: route.fromCity, to: route.toCity) ?? tripTitle
        fields.confirmationCode = NonEmpty.string(reservation.identifiers?.publicFacingIdentifier)
            ?? reservation.identifiers?.publicId
        fields.airline = route.airline
        fields.passengerCount = reservation.passengerCount
        fields.flightDepartureOffsetSeconds = ISODateTime.offsetSeconds(from: reservation.startDateTime)
        fields.flightArrivalOffsetSeconds = ISODateTime.offsetSeconds(from: reservation.endDateTime)
    }
}
