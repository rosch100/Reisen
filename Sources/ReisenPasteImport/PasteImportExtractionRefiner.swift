import Foundation
import ReisenDomain

/// Nachbearbeitung der Modell-Extrakte in fester Reihenfolge (SSOT).
enum PasteImportExtractionRefiner {
    static func refine(
        _ extractions: [PasteImportExtraction],
        sourceText: String?
    ) -> [PasteImportExtraction] {
        let coalesced = PasteImportExtractionCoalescer.coalescing(extractions)
        let typed = PasteImportExtractionTypeHint.applying(coalesced)
        let dated = PasteImportExtractionCompleter.fillingOmittedTravelDates(
            typed,
            from: sourceText
        )
        return PasteImportSourceGrounding.keepingGrounded(dated, in: sourceText)
    }
}
