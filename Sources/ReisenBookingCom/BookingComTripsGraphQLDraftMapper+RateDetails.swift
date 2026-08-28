import Foundation
import ReisenDomain

extension BookingComTripsGraphQLParser {
    func rateDetails(
        from reservation: GraphQLReservation,
        bookingType: BookingType,
        fields: MappedFields
    ) -> BookingRateDetails? {
        let activityTickets = bookingType == .activity ? positiveCount(reservation.ticketCount) : nil
        let roomCount = bookingType == .hotel ? reservation.numOfRooms : nil
        let passengerCount = fields.passengerCount ?? activityTickets
        let price = reservation.price
        let hasMeta = fields.airline != nil
            || passengerCount != nil
            || fields.roomCategory != nil
            || roomCount != nil
        guard price != nil || hasMeta else { return nil }
        return BookingRateDetails(
            totalPriceAmount: price?.amount,
            totalPriceCurrency: price?.currency,
            roomCategory: fields.roomCategory,
            guestCount: activityTickets,
            roomCount: roomCount,
            airline: fields.airline,
            passengerCount: passengerCount
        )
    }

    private func positiveCount(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }
}
