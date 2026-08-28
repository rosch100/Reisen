import Foundation
import ReisenDomain

extension ActivityListParser {
    static let travelProductKeys: Set<String> = [
        "hotel", "flight", "ferry", "holidayflat", "package", "rentalcar"
    ]

    func productKey(from activity: [String: Any]) -> String {
        if let product = activity["product"] as? [String: Any] {
            if let key = product["key"] as? String { return key.lowercased() }
        }
        return ""
    }
}
