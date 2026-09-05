import Foundation
import ReisenDomain

/// Maps GraphQL reservations to `ProviderBookingDraft`.
extension BookingComTripsGraphQLParser {
    struct MappedFields {
        var title: String?
        var locationFrom: String?
        var locationTo: String?
        var locationToAddress: String?
        var operatorName: String?
        var confirmationCode: String?
        var roomCategory: String?
        var hotelOffsetSeconds: Int?
        var hotelCheckInMinutes: Int?
        var hotelCheckOutMinutes: Int?
        var flightDepartureOffsetSeconds: Int?
        var flightArrivalOffsetSeconds: Int?
        var airline: String?
        var passengerCount: Int?
    }

    func draft(
        from reservation: GraphQLReservation,
        tripTitle: String?,
        tripCanceled: Bool = false
    ) -> ProviderBookingDraft? {
        guard let externalUrl = BookingComParsing.absoluteBookingURL(
            reservation.bookingUrl ?? reservation.reservationDetailsURL
        ) else {
            return nil
        }
        guard let startISO = reservation.startDateTime, let endISO = reservation.endDateTime else {
            return nil
        }

        let bookingType = bookingType(of: reservation)
        let fields = mappedFields(from: reservation, bookingType: bookingType, tripTitle: tripTitle)
        let offset = fields.hotelOffsetSeconds ?? ISODateTime.offsetSeconds(from: startISO)
        let deadlines = deadline(from: reservation.policy, hotelOffsetSeconds: offset).map { [$0] } ?? []

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
                operatorName: fields.operatorName,
                isAllDay: activityIsAllDay(bookingType, startISO: startISO, endISO: endISO),
                statusRaw: catalogStatusRaw(
                    reservationStatus: reservation.reservationStatus,
                    tripCanceled: tripCanceled
                ),
                deadlines: deadlines,
                rateDetails: rateDetails(from: reservation, bookingType: bookingType, fields: fields),
                hotelOffsetSeconds: fields.hotelOffsetSeconds,
                hotelCheckInMinutes: fields.hotelCheckInMinutes,
                hotelCheckOutMinutes: fields.hotelCheckOutMinutes,
                flightDepartureOffsetSeconds: fields.flightDepartureOffsetSeconds,
                flightArrivalOffsetSeconds: fields.flightArrivalOffsetSeconds
            )
        )
    }

    private func activityIsAllDay(
        _ bookingType: BookingType,
        startISO: String,
        endISO: String
    ) -> Bool? {
        guard bookingType == .activity else { return nil }
        let hasClock = BookingComParsing.clockMinutes(from: startISO) != nil
            || BookingComParsing.clockMinutes(from: endISO) != nil
        return hasClock ? false : nil
    }
}
