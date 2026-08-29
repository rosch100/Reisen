import Foundation
import ReisenDomain

/// Setzt `bookingType` aus engen Titel-/Operator-Aliasen, wenn das Modell ihn wegließ.
///
/// Alias-SSOT: `PasteImportBookingLabel.typeHint(fromToken:)`. Mehrere widersprüchliche
/// Hint-Tokens → kein Hint (kein Raten).
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
            guard let type = PasteImportBookingLabel.typeHint(fromToken: token) else { continue }
            if let found, found != type { return nil }
            found = type
        }
        return found
    }
}
