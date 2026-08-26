import Foundation
import ReisenDomain

extension ActivityListParser {
    func mapBookingType(_ productKey: String) -> BookingType {
        switch productKey {
        case "hotel", "holidayflat", "package":
            return .hotel
        case "flight":
            return .flight
        case "ferry":
            return .ferry
        default:
            return .other
        }
    }
}
