import Foundation

/// Verwirft Extractions ohne Typ oder Startzeitpunkt und macht die restlichen zu typisierten Drafts.
public enum PasteImportFilter {
    public static func apply(_ extractions: [PasteImportExtraction]) -> [PasteImportDraft] {
        extractions.compactMap(PasteImportDraft.init(from:))
    }
}
