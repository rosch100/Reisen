import Foundation
import ReisenDomain

/// Setzt `bookingType` nur aus belegten Titel-/Operator-Hinweisen, wenn das Modell ihn wegließ.
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
        guard let key = letters(raw), !key.isEmpty else { return nil }
        if key.contains("flixbus") || key.contains("fernbus") || key.hasPrefix("bus") {
            return .train
        }
        if key.contains("getyourguide")
            || key.contains("eventbrite")
            || key.contains("tour")
            || key.contains("ausflug")
            || key.contains("event")
        {
            return .activity
        }
        return nil
    }

    private static func letters(_ raw: String?) -> String? {
        guard let raw = NonEmpty.string(raw) else { return nil }
        return raw.lowercased().filter(\.isLetter)
    }
}
