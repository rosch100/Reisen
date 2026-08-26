import Foundation
import ReisenDomain

extension BookingComFlightOrderParser {
    func mappedAllowances(
        from luggage: [FlightTravellerLuggage],
        travellerReference: String
    ) -> [BaggageAllowance] {
        luggage
            .filter { $0.travellerReference == travellerReference }
            .compactMap(\.luggageAllowance)
            .map { allowance in
                BaggageAllowance(
                    type: baggageType(from: allowance.luggageType),
                    pieceCount: allowance.maxPiece,
                    weightKg: allowance.maxWeightPerPiece.map(Double.init),
                    sectionID: nil,
                    airlineCode: nil,
                    fromLabel: nil,
                    toLabel: nil
                )
            }
    }

    func personalItemAllowance(
        cabin: [FlightTravellerLuggage],
        travellerReference: String
    ) -> BaggageAllowance? {
        // Booking.com often marks an additional "personalItem" alongside HAND luggage.
        guard cabin.first(where: { $0.travellerReference == travellerReference })?.personalItem == true else {
            return nil
        }
        return BaggageAllowance(
            type: .personalItem,
            pieceCount: 1,
            weightKg: nil,
            sectionID: nil,
            airlineCode: nil,
            fromLabel: nil,
            toLabel: nil
        )
    }
}
