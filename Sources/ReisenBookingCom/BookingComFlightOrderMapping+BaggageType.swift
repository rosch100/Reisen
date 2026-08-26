import Foundation
import ReisenDomain

extension BookingComFlightOrderParser {
    func baggageType(from luggageType: String?) -> BaggageType {
        guard let luggageType else { return .unknown }
        switch luggageType.uppercased() {
        case "CHECKED_IN": return .checkedBag
        case "HAND": return .cabinBag
        case "PERSONAL_ITEM": return .personalItem
        default: return .unknown
        }
    }
}
