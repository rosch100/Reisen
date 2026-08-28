import Foundation
import ReisenDomain

extension OpodoTripsGraphQLParser {
    func draft(from trip: OpodoGraphQLTrip) -> ProviderBookingDraft? {
        guard let tdToken = trip.tdToken, !tdToken.isEmpty else { return nil }
        let externalUrl = OpodoWeb.tripDetailsURL(token: tdToken)
        let rateDetails = rateDetails(from: trip.price)
        if let hotel = trip.accommodationBooking {
            return draftHotel(
                trip: trip,
                hotel: hotel,
                externalUrl: externalUrl,
                rateDetails: rateDetails
            )
        }
        if let itinerary = trip.itinerary, isPlaneItinerary(itinerary) {
            return draftFlight(
                trip: trip,
                itinerary: itinerary,
                externalUrl: externalUrl,
                rateDetails: rateDetails
            )
        }
        return nil
    }

    private func isPlaneItinerary(_ itinerary: OpodoGraphQLItinerary) -> Bool {
        itinerary.transportTypes?.contains {
            $0.caseInsensitiveCompare("PLANE") == .orderedSame
        } == true
    }
}
