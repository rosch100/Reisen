import Foundation
import ReisenDomain

/// Setzt `bookingType` aus **engen** Titel-/Operator-Aliasen, wenn das Modell ihn wegließ.
///
/// Nur Bus-/Tour-/GYG-Tokens — keine breiten Mapper wie `event`, `ice`, `airline` (die gehören
/// dem Modell bzw. `PasteImportBookingLabel` beim Generable-Mapping).
/// Mehrere widersprüchliche Hint-Tokens → kein Hint (kein Raten).
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
        var found: BookingType?
        for token in PasteImportTextTokens.tokens(in: raw) {
            guard let type = narrowAliases[token] else { continue }
            if let found, found != type { return nil }
            found = type
        }
        return found
    }

    /// Whitelist: nur Tokens, die ohne Modellkontext den Typ sicher festlegen.
    private static let narrowAliases: [String: BookingType] = [
        "bus": .train,
        "flixbus": .train,
        "fernbus": .train,
        "coach": .train,
        "omnibus": .train,
        "tour": .activity,
        "getyourguide": .activity,
        "ausflug": .activity,
    ]
}
