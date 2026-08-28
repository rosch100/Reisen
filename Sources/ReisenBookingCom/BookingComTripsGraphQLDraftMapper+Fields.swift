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
        case .activity:
            applyAttractionMappedFields(reservation, into: &fields, tripTitle: tripTitle)
        case .carRental:
            applyCarMappedFields(reservation, into: &fields, tripTitle: tripTitle)
        case .other where isPrebookTaxi(reservation):
            applyTaxiMappedFields(reservation, into: &fields, tripTitle: tripTitle)
        case .other, .ferry, .train:
            applyFallbackMappedFields(reservation, into: &fields, tripTitle: tripTitle)
        }
        return fields
    }

    private func applyAttractionMappedFields(
        _ reservation: GraphQLReservation,
        into fields: inout MappedFields,
        tripTitle: String?
    ) {
        fields.title = NonEmpty.string(reservation.product?.name) ?? tripTitle
        fields.locationTo = NonEmpty.string(reservation.product?.location?.city)
        fields.confirmationCode = publicConfirmationCode(reservation)
    }

    private func applyCarMappedFields(
        _ reservation: GraphQLReservation,
        into fields: inout MappedFields,
        tripTitle: String?
    ) {
        let product = reservation.product
        fields.title = NonEmpty.string(product?.name) ?? NonEmpty.string(product?.carClass) ?? tripTitle
        fields.locationFrom = NonEmpty.string(reservation.pickUpLocation?.city)
        fields.locationTo = NonEmpty.string(reservation.dropOffLocation?.city)
        fields.operatorName = NonEmpty.string(product?.supplier)
        fields.roomCategory = NonEmpty.string(product?.carClass)
        fields.confirmationCode = publicConfirmationCode(reservation)
    }

    private func applyFallbackMappedFields(
        _ reservation: GraphQLReservation,
        into fields: inout MappedFields,
        tripTitle: String?
    ) {
        fields.title = tripTitle
        fields.confirmationCode = publicConfirmationCode(reservation)
    }

    private func applyTaxiMappedFields(
        _ reservation: GraphQLReservation,
        into fields: inout MappedFields,
        tripTitle: String?
    ) {
        let pickup = taxiPickupLabel(reservation.pickUp?.location)
        let dropoff = NonEmpty.string(reservation.dropOff?.location?.city)
        fields.title = PlaceLabel.route(from: pickup, to: dropoff)
            ?? NonEmpty.string(reservation.product?.vehicleTypeText)
            ?? tripTitle
        fields.locationFrom = pickup
        fields.locationTo = dropoff
        fields.operatorName = NonEmpty.string(reservation.product?.providerName)
        fields.confirmationCode = publicConfirmationCode(
            reservation,
            preferring: reservation.bookingRef
        )
    }

    private func taxiPickupLabel(_ location: GraphQLLocation?) -> String? {
        NonEmpty.string(location?.airportName)
            ?? PlaceLabel.make(city: location?.city, iata: location?.airportCode)
    }
}
