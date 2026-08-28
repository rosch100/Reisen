import Foundation

extension BookingBoardType {
    public static func parse(_ raw: String?) -> BookingBoardType {
        guard let trimmed = NonEmpty.string(raw) else { return .unknown }
        if let exact = BookingBoardType(rawValue: trimmed) {
            return exact
        }
        switch trimmed.uppercased() {
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

    /// Explizites API-Bool: `true` → Frühstück, `false` → nur Zimmer, fehlend → unbekannt.
    public static func parse(breakfastIncluded: Bool?) -> BookingBoardType {
        switch breakfastIncluded {
        case true:
            return .breakfastIncluded
        case false:
            return .roomOnly
        case nil:
            return .unknown
        }
    }

    /// Merge-Flag für `BookingRateDetails.includedBreakfast`.
    /// Unbekannt bleibt `nil` (kein Clobber); Frühstück `true`; jedes andere bekannte Board `false`.
    public var includedBreakfast: Bool? {
        switch self {
        case .unknown:
            return nil
        case .breakfastIncluded:
            return true
        case .roomOnly, .halfBoard, .fullBoard:
            return false
        }
    }
}
