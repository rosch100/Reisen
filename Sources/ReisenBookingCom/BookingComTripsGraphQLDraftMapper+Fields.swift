import Foundation
import ReisenDomain

extension BookingComTripsGraphQLParser {
    func mappedFields(
        from reservation: GraphQLReservation,
        bookingType: BookingType,
        tripTitle: String?
    ) -> MappedFields {
        var fields = MappedFields()
        switch bookingType {
        case .hotel:
            applyHotelMappedFields(reservation, into: &fields, tripTitle: tripTitle)
        case .flight:
            applyFlightMappedFields(reservation, into: &fields, tripTitle: tripTitle)
        case .ferry, .activity, .other:
            fields.title = tripTitle
            fields.confirmationCode = reservation.identifiers?.publicId
        }
        return fields
    }
}
