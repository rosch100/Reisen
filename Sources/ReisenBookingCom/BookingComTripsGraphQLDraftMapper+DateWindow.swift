import Foundation
import ReisenDomain

extension BookingComTripsGraphQLParser {
    func draftDateWindow(
        reservation: GraphQLReservation,
        bookingType: BookingType,
        fields: inout MappedFields
    ) -> (startAt: Date, endAt: Date)? {
        switch bookingType {
        case .hotel:
            return hotelDraftDateWindow(reservation: reservation, fields: &fields)
        case .flight, .ferry, .activity, .other:
            return flightLikeDraftDateWindow(reservation: reservation, bookingType: bookingType, fields: &fields)
        }
    }

    func hotelDraftDateWindow(
        reservation: GraphQLReservation,
        fields: inout MappedFields
    ) -> (startAt: Date, endAt: Date)? {
        // Hotels: nur Kalenderdatum aus ISO (Uhrzeit/TZ verwerfen).
        guard let startDay = BookingComParsing.dateOnly(fromISO: reservation.startDateTime),
              let endDay = BookingComParsing.dateOnly(fromISO: reservation.endDateTime) else {
            return nil
        }
        fields.hotelOffsetSeconds = fields.hotelOffsetSeconds ?? startDay.offsetSeconds
        if fields.deadlines.isEmpty,
           let policyDeadline = deadline(
            from: reservation.policy,
            hotelOffsetSeconds: fields.hotelOffsetSeconds
           ) {
            fields.deadlines = [policyDeadline]
        }
        return (startDay.date, endDay.date)
    }

    func flightLikeDraftDateWindow(
        reservation: GraphQLReservation,
        bookingType: BookingType,
        fields: inout MappedFields
    ) -> (startAt: Date, endAt: Date)? {
        // Flüge: Wanduhr als UTC + Offset; Normalizer macht Absolutzeit.
        guard let startStorage = BookingComParsing.wallClockStorage(fromISO: reservation.startDateTime),
              let endStorage = BookingComParsing.wallClockStorage(fromISO: reservation.endDateTime) else {
            return nil
        }
        if bookingType == .flight || bookingType == .ferry {
            fields.flightDepartureOffsetSeconds = fields.flightDepartureOffsetSeconds ?? startStorage.offsetSeconds
            fields.flightArrivalOffsetSeconds = fields.flightArrivalOffsetSeconds ?? endStorage.offsetSeconds
        }
        return (startStorage.wallClockAsUTC, endStorage.wallClockAsUTC)
    }
}
