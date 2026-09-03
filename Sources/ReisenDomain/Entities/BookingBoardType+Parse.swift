import Foundation

extension BookingBoardType {
    public static func parse(_ raw: String?) -> BookingBoardType {
        guard let trimmed = NonEmpty.string(raw) else { return .unknown }
        if let exact = BookingBoardType(rawValue: trimmed) {
            return exact
        }
        switch trimmed.uppercased() {
        case "BB", "BREAKFAST", "BREAKFAST_INCLUDED":
            return .breakfastIncluded
        case "HB", "HALF_BOARD", "HALFBOARD":
            return .halfBoard
        case "FB", "FULL_BOARD", "FULLBOARD":
            return .fullBoard
        case "RO", "ROOM_ONLY", "ROOMONLY", "NONE":
            return .roomOnly
        default:
            return parseGermanOrFreeText(trimmed)
        }
    }

    /// Check24 `mealTypeLabel` und ähnliche Freitexte (DE).
    private static func parseGermanOrFreeText(_ raw: String) -> BookingBoardType {
        let folded = raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE"))
            .lowercased()
        if isRoomOnlyFreeText(folded) {
            return .roomOnly
        }
        if folded.contains("vollpension") || folded.contains("full board") {
            return .fullBoard
        }
        if folded.contains("halbpension") || folded.contains("half board") {
            return .halfBoard
        }
        if folded.contains("fruhstuck") || folded.contains("breakfast") {
            return .breakfastIncluded
        }
        return .unknown
    }

    /// Negationen vor positivem „Frühstück“/„breakfast“-Substring (folded Input).
    private static let roomOnlyFreeTextNeedles = [
        "ohne verpflegung",
        "ohne fruhstuck",
        "kein fruhstuck",
        "fruhstuck nicht inklusive",
        "nur ubernachtung",
        "room only",
        "without breakfast",
        "no breakfast",
        "breakfast not included",
    ]

    private static func isRoomOnlyFreeText(_ folded: String) -> Bool {
        roomOnlyFreeTextNeedles.contains { folded.contains($0) }
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
