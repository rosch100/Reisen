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
        guard let startISO = reservation.startDateTime, let endISO = reservation.endDateTime else {
            return nil
        }

        let bookingType = bookingType(of: reservation)
        var fields = mappedFields(from: reservation, bookingType: bookingType, tripTitle: tripTitle)
        if fields.deadlines.isEmpty {
            let offset = fields.hotelOffsetSeconds ?? ISODateTime.offsetSeconds(from: startISO)
            if let policyDeadline = deadline(from: reservation.policy, hotelOffsetSeconds: offset) {
                fields.deadlines = [policyDeadline]
            }
        }

        return DraftAssembler.draft(
            from: ProviderBookingFacts(
                provider: .booking,
                bookingType: bookingType,
                start: .iso(startISO),
                end: .iso(endISO),
                title: fields.title,
                confirmationCode: fields.confirmationCode,
                externalUrl: externalUrl,
                locationFrom: fields.locationFrom,
                locationTo: fields.locationTo,
                locationToAddress: fields.locationToAddress,
                statusRaw: reservation.reservationStatus,
                deadlines: fields.deadlines,
                rateDetails: rateDetails(from: reservation, bookingType: bookingType, fields: fields),
                hotelOffsetSeconds: fields.hotelOffsetSeconds,
                hotelCheckInMinutes: fields.hotelCheckInMinutes,
                hotelCheckOutMinutes: fields.hotelCheckOutMinutes,
                flightDepartureOffsetSeconds: fields.flightDepartureOffsetSeconds,
                flightArrivalOffsetSeconds: fields.flightArrivalOffsetSeconds
            )
        )
    }
}
