import Foundation
import ReisenDomain

extension ActivityListParser {
    func mapBookingStatus(_ statusKey: String) -> BookingStatus {
        switch statusKey {
        case "cancelled", "canceled", "terminated":
            return .cancelled
        case "upcoming", "active":
            return .confirmed
        default:
            return .unknown
        }
    }
}
