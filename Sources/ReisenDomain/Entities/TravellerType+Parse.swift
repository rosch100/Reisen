import Foundation

extension TravellerType {
    public static func parse(_ raw: String?) -> TravellerType {
        guard let trimmed = NonEmpty.string(raw) else { return .unknown }

        if let exact = TravellerType(rawValue: trimmed.lowercased()) {
            return exact
        }

        let lower = trimmed.lowercased()
        if lower == "inf" || lower.contains("infant") || lower.contains("baby") {
            return .infant
        }
        if lower == "chd" || lower.contains("child") || lower.contains("youth") {
            return .child
        }
        if lower == "adt" || lower.contains("adult") {
            return .adult
        }
        return .unknown
    }
}
