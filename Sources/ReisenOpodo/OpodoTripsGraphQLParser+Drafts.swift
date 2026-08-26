import Foundation
import ReisenDomain

extension OpodoTripsGraphQLParser {
    func draft(from trip: OpodoGraphQLTrip) -> ProviderBookingDraft? {
        guard let tdToken = trip.tdToken, !tdToken.isEmpty else { return nil }
        let externalUrl = "https://www.opodo.de/travel/secure/#tripdetails/td=\(tdToken)"
        let rateDetails = rateDetails(from: trip.price)
        if let hotel = trip.accommodationBooking {
            return draftHotel(
                trip: trip,
                hotel: hotel,
                externalUrl: externalUrl,
                rateDetails: rateDetails
            )
        }

        if let itinerary = trip.itinerary {
            return draftFlight(
                trip: trip,
                itinerary: itinerary,
                externalUrl: externalUrl,
                rateDetails: rateDetails
            )
        }

        return nil
    }
}
