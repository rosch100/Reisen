import Foundation
import ReisenDomain

extension BookingComFlightOrderParser {
    func baggageAllowances(
        travellerReference: String,
        checked: [FlightTravellerLuggage],
        cabin: [FlightTravellerLuggage]
    ) -> [BaggageAllowance] {
        var result = mappedAllowances(from: checked, travellerReference: travellerReference)
        result.append(contentsOf: mappedAllowances(from: cabin, travellerReference: travellerReference))
        if let personal = personalItemAllowance(cabin: cabin, travellerReference: travellerReference) {
            result.append(personal)
        }
        return result
    }
}
