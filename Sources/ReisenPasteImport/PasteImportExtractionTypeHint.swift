import Foundation
import ReisenDomain

/// Setzt `bookingType` nur aus belegten Titel-/Operator-**Tokens**, wenn das Modell ihn wegließ.
///
/// Keine Substring-Fallen: „Business“, „Busan“, „Touristenhotel“, „preventive“ bleiben unberührt.
public enum PasteImportExtractionTypeHint {
    public static func applying(_ extractions: [PasteImportExtraction]) -> [PasteImportExtraction] {
        extractions.map(apply)
    }

    private static func apply(_ extraction: PasteImportExtraction) -> PasteImportExtraction {
        guard extraction.bookingType == nil else { return extraction }
        var result = extraction
        if let type = hint(in: extraction.title) ?? hint(in: extraction.operatorName) {
            result.bookingType = type
        }
        return result
    }

    private static func hint(in raw: String?) -> BookingType? {
        let tokens = tokens(in: raw)
        guard !tokens.isEmpty else { return nil }
        if tokens.contains(where: trainTokens.contains) { return .train }
        if tokens.contains(where: activityTokens.contains) { return .activity }
        return nil
    }

    private static func tokens(in raw: String?) -> Set<String> {
        guard let raw = NonEmpty.string(raw) else { return [] }
        let folded = raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        return Set(
            folded
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
                .filter { !$0.isEmpty }
        )
    }

    private static let trainTokens: Set<String> = [
        "bus",
        "flixbus",
        "fernbus",
        "coach",
        "omnibus",
    ]

    private static let activityTokens: Set<String> = [
        "tour",
        "ausflug",
        "event",
        "getyourguide",
        "eventbrite",
    ]
}
