import Foundation
import ReisenDomain

extension Check24FlightPassengersAndLuggageParser {
    func baggageType(from check24Type: String) -> BaggageType {
        let normalized = check24Type.lowercased()
        if normalized.contains("checked") && normalized.contains("bag") {
            return .checkedBag
        }
        if normalized.contains("carry-on-small-bag") {
            return .personalItem
        }
        if normalized.contains("carry-on-bag") {
            return .cabinBag
        }
        // Fail-soft: unknown types should still be preserved as "unknown".
        return .unknown
    }
}
