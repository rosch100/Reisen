import Foundation
import ReisenDomain

extension OpodoTripCancellationGraphQLParser {
    func hotelProductOrFallbackDeadlines(from trip: OpodoCancellationTripDTO) -> [CancellationDeadline] {
        // HAR UI: Stornierungsrichtlinie = accommodationProductBooking.cancellationPolicies
        let productOptions = trip.accommodationProductBooking?.cancellationPolicies?.cancellationOptions
        let productDeadlines = deadlinesFromCancellationOptions(productOptions, policyLabel: OpodoCancellationPolicyLabel.policy)
        if !productDeadlines.isEmpty {
            return productDeadlines
        }
        if let hotel = trip.accommodationBooking {
            return hotelDeadlinesFallback(from: hotel)
        }
        return []
    }
}
