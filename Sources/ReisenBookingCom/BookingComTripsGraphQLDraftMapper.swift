import Foundation
import ReisenDomain

/// Maps GraphQL reservations to `ProviderBookingDraft`.
extension BookingComTripsGraphQLParser {
    struct MappedFields {
        var title: String?
        var locationFrom: String?
        var locationTo: String?
        var locationToAddress: String?
        var confirmationCode: String?
        var hotelOffsetSeconds: Int?
        var hotelCheckInMinutes: Int?
        var hotelCheckOutMinutes: Int?
        var flightDepartureOffsetSeconds: Int?
        var flightArrivalOffsetSeconds: Int?
        var deadlines: [CancellationDeadline] = []
        var airline: String?
        var passengerCount: Int?
    }

    func draft(from reservation: GraphQLReservation, tripTitle: String?) -> ProviderBookingDraft? {
        guard let externalUrl = BookingComParsing.absoluteBookingURL(
            reservation.bookingUrl ?? reservation.reservationDetailsURL
        ) else {
            return nil
        }

        let bookingType = bookingType(of: reservation)
        var fields = mappedFields(from: reservation, bookingType: bookingType, tripTitle: tripTitle)
        guard let window = draftDateWindow(
            reservation: reservation,
            bookingType: bookingType,
            fields: &fields
        ) else {
            return nil
        }

        return ProviderBookingDraft(
            provider: .booking,
            bookingType: bookingType,
            title: fields.title,
            confirmationCode: fields.confirmationCode,
            externalUrl: externalUrl,
            startAt: window.startAt,
            endAt: window.endAt,
            locationFrom: fields.locationFrom,
            locationTo: fields.locationTo,
            locationToAddress: fields.locationToAddress,
            status: status(from: reservation.reservationStatus),
            deadlines: fields.deadlines,
            rateDetails: rateDetails(from: reservation, bookingType: bookingType, fields: fields),
            hotelOffsetSeconds: fields.hotelOffsetSeconds,
            hotelCheckInMinutes: fields.hotelCheckInMinutes,
            hotelCheckOutMinutes: fields.hotelCheckOutMinutes,
            flightDepartureOffsetSeconds: fields.flightDepartureOffsetSeconds,
            flightArrivalOffsetSeconds: fields.flightArrivalOffsetSeconds
        )
    }
}
