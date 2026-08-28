import Foundation
import ReisenDomain

extension BookingComTripsGraphQLParser {
    func rateDetails(
        from reservation: GraphQLReservation,
        bookingType: BookingType,
        fields: MappedFields
    ) -> BookingRateDetails? {
        let guestCount = bookingType == .activity ? reservation.ticketCount : nil
        let roomCount = bookingType == .hotel ? reservation.numOfRooms : nil
        let price = reservation.price
        let hasMeta = fields.airline != nil
            || fields.passengerCount != nil
            || fields.roomCategory != nil
            || guestCount != nil
            || roomCount != nil
        guard price != nil || hasMeta else { return nil }
        return BookingRateDetails(
            totalPriceAmount: price?.amount,
            totalPriceCurrency: price?.currency,
            roomCategory: fields.roomCategory,
            guestCount: guestCount,
            roomCount: roomCount,
            airline: fields.airline,
            passengerCount: fields.passengerCount
        )
    }
}
