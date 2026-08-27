import Foundation
import ReisenDomain

extension BookingComTripsGraphQLParser {
    func flightRoute(_ components: [GraphQLFlightComponent]?) -> (
        fromCity: String?,
        toCity: String?,
        fromLabel: String?,
        toLabel: String?,
        airline: String?
    ) {
        let parts = (components ?? []).compactMap(\.parts).flatMap { $0 }
        guard let first = parts.first, let last = parts.last else {
            return (nil, nil, nil, nil, nil)
        }
        let fromCity = first.startLocation?.location?.city
        let toCity = last.endLocation?.location?.city
        return (
            fromCity,
            toCity,
            PlaceLabel.make(city: fromCity, iata: first.startLocation?.iata),
            PlaceLabel.make(city: toCity, iata: last.endLocation?.iata),
            first.marketingCarrier?.code
        )
    }
}
