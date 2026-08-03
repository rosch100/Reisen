import Foundation
import ReisenDomain

extension Check24FlightPassengersAndLuggageParser {
    /// Maps `includedLuggage` from the status endpoint into baggage allowances.
    ///
    /// Semantics:
    /// - We aggregate across all itinerary flights (outbound + inbound) to represent per-traveller totals.
    public func baggageAllowances(from statusJSON: String) throws -> [BaggageAllowance] {
        let payload = try decode(StatusEnvelope.self, from: statusJSON)
        let included = includedLuggageItems(from: payload.data.itinerary)
        let (piecesByType, weightKgByType) = aggregateBaggage(from: included)
        return makeBaggageAllowances(piecesByType: piecesByType, weightKgByType: weightKgByType)
    }

    func includedLuggageItems(from itinerary: StatusItinerary) -> [IncludedLuggageItem] {
        let flights = itinerary.flights
        // Check24 gibt oft `includedLuggageEqual=true` für Hin-/Rückflug an.
        // Dann ist die „Luggage“-Anzeige im UI typischerweise pro Strecke identisch
        // und sollte nicht doppelt gezählt werden.
        if itinerary.includedLuggageEqual == true, let first = flights.first {
            return first.includedLuggage
        }
        return flights.flatMap(\.includedLuggage)
    }
}
