import Foundation
import ReisenDomain

/// Füllt fehlendes `startAt` aus dem Quelltext, wenn genau eine typisierte Buchung kein Datum hat.
///
/// Kein Überschreiben, kein Raten bei mehreren unvollständigen Segmenten.
public enum PasteImportExtractionCompleter {
    public static func fillingOmittedTravelDates(
        _ extractions: [PasteImportExtraction],
        from text: String?
    ) -> [PasteImportExtraction] {
        guard let text, let fallback = PasteImportTravelDateFromText.startAt(in: text) else {
            return extractions
        }
        let missing = extractions.indices.filter { index in
            extractions[index].bookingType != nil && extractions[index].startAt == nil
        }
        guard missing.count == 1, let index = missing.first else { return extractions }
        var copy = extractions
        copy[index].startAt = fallback
        return copy
    }
}
