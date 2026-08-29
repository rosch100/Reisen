import Foundation

/// Macht aus rohen Extractions abgleichbare Kandidaten.
///
/// Reihenfolge: `PasteImportFilter` verwirft Extractions ohne Typ oder Start,
/// danach wird jeder Draft über `PasteImportMatching` gegen den Bestand geprüft.
/// Der Index wird einmal gebaut und für alle Drafts wiederverwendet.
public enum PasteImportPipeline {
    public static func candidates(
        from extractions: [PasteImportExtraction],
        existing: [Booking],
        calendar: Calendar,
        normalizer: BookingTimeNormalizer
    ) -> [PasteImportCandidate] {
        let index = SyncBookingMatchIndex(existing: existing, calendar: calendar)
        return PasteImportFilter.apply(extractions).map { draft in
            PasteImportCandidate(
                draft: draft,
                match: PasteImportMatching.match(
                    draft: draft,
                    existing: existing,
                    index: index,
                    calendar: calendar,
                    normalizer: normalizer
                )
            )
        }
    }
}
