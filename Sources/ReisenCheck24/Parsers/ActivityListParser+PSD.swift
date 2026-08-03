import Foundation

extension ActivityListParser {
    func productSpecificData(from activity: [String: Any]) -> [String: Any] {
        (activity["product_specific_data"] as? [String: Any])
            ?? (activity["productSpecificData"] as? [String: Any])
            ?? [:]
    }
}
