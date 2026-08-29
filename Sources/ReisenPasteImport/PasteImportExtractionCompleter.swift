import Foundation
import ReisenDomain

/// Füllt fehlendes `startAt` aus dem Quelltext.
///
/// - Genau eine Buchung ohne Start → erstes Reisedatum.
/// - Mehrere Buchungen, alle mit Typ und ohne Start, und genau so viele Reisedaten im Text → 1:1.
/// - Gemischte Fälle (manche schon mit Start) bleiben unverändert — kein Raten der Zuordnung.
public enum PasteImportExtractionCompleter {
    public static func fillingOmittedTravelDates(
        _ extractions: [PasteImportExtraction],
        from text: String?
    ) -> [PasteImportExtraction] {
        guard let text, !extractions.isEmpty else { return extractions }

        if extractions.count == 1,
           var only = extractions.first,
           only.bookingType != nil,
           only.startAt == nil,
           let fallback = PasteImportTravelDateFromText.startAt(in: text)
        {
            only.startAt = fallback
            return [only]
        }

        guard extractions.allSatisfy({ $0.bookingType != nil && $0.startAt == nil }) else {
            return extractions
        }
        let dates = PasteImportTravelDateFromText.allStartAts(in: text)
        guard dates.count == extractions.count else { return extractions }
        return zip(extractions, dates).map { extraction, date in
            var filled = extraction
            filled.startAt = date
            return filled
        }
    }
}
