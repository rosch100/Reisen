import Foundation
import ReisenDomain

extension BookingComTripsGraphQLParser {
    func rateDetails(
        from reservation: GraphQLReservation,
        bookingType: BookingType,
        fields: MappedFields
    ) -> BookingRateDetails? {
        if let price = reservation.price {
            return BookingRateDetails(
                totalPriceAmount: price.amount,
                totalPriceCurrency: price.currency,
                roomCount: bookingType == .hotel ? reservation.numOfRooms : nil,
                airline: fields.airline,
                passengerCount: fields.passengerCount
            )
        }
        if bookingType == .hotel, let rooms = reservation.numOfRooms {
            return BookingRateDetails(roomCount: rooms)
        }
        if fields.airline != nil || fields.passengerCount != nil {
            return BookingRateDetails(airline: fields.airline, passengerCount: fields.passengerCount)
        }
        return nil
    }
}
