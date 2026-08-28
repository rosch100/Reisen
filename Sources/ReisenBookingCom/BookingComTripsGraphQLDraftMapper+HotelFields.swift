import Foundation
import ReisenDomain

extension BookingComTripsGraphQLParser {
    func applyHotelMappedFields(
        _ reservation: GraphQLReservation,
        into fields: inout MappedFields,
        tripTitle: String?
    ) {
        fields.title = reservation.propertyData?.name ?? tripTitle
        fields.locationTo = reservation.propertyData?.location?.city
        fields.locationToAddress = reservation.propertyData?.location?.address
        fields.confirmationCode = reservation.identifiers?.hotelReservationId
            ?? reservation.identifiers?.publicId
        if let checkInStart = reservation.checkIn?.start {
            fields.hotelOffsetSeconds = ISODateTime.offsetSeconds(from: checkInStart)
            fields.hotelCheckInMinutes = BookingComParsing.clockMinutes(from: checkInStart)
        }
        if let checkOutEnd = reservation.checkOut?.end {
            fields.hotelCheckOutMinutes = BookingComParsing.clockMinutes(from: checkOutEnd)
        }
    }
}
