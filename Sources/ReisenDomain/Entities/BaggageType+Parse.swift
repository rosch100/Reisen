import Foundation

extension BaggageType {
    public static func parse(_ raw: String?) -> BaggageType {
        guard let trimmed = NonEmpty.string(raw) else { return .unknown }

        if let exact = BaggageType(rawValue: trimmed) {
            return exact
        }

        switch trimmed.uppercased() {
        case "CHECKED_IN", "CHECKED", "CHECKED_BAG":
            return .checkedBag
        case "HAND", "CABIN", "CABIN_BAG":
            return .cabinBag
        case "PERSONAL_ITEM", "PERSONAL":
            return .personalItem
        default:
            break
        }

        let lower = trimmed.lowercased()
        if lower.contains("carry-on-small") {
            return .personalItem
        }
        if lower.contains("checked") && lower.contains("bag") {
            return .checkedBag
        }
        if lower.contains("carry-on") || lower.contains("cabin") || lower.contains("hand") {
            return .cabinBag
        }
        return .unknown
    }
}
