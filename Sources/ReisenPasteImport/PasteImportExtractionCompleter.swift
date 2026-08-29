import Foundation
import ReisenDomain

/// Füllt fehlendes `startAt` aus dem Quelltext, wenn genau **eine** Buchung im Payload steht.
///
/// Bei mehreren Extrakten liefert der Textparser nur das erste Reisedatum der ganzen Quelle —
/// das darf nicht einer anderen Buchung zugeordnet werden.
public enum PasteImportExtractionCompleter {
    public static func fillingOmittedTravelDates(
        _ extractions: [PasteImportExtraction],
        from text: String?
    ) -> [PasteImportExtraction] {
        guard extractions.count == 1,
              var only = extractions.first,
              only.bookingType != nil,
              only.startAt == nil,
              let text,
              let fallback = PasteImportTravelDateFromText.startAt(in: text)
        else {
            return extractions
        }
        only.startAt = fallback
        return [only]
    }
}
