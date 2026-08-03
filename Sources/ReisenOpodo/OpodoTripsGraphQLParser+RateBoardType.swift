import Foundation
import ReisenDomain

extension OpodoTripsGraphQLParser {
    func boardType(from raw: String?) -> BookingBoardType {
        switch raw?.uppercased() {
        case "BB", "BREAKFAST":
            return .breakfastIncluded
        case "HB":
            return .halfBoard
        case "FB":
            return .fullBoard
        case "RO", "ROOM_ONLY":
            return .roomOnly
        default:
            return .unknown
        }
    }
}
