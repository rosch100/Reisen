import Foundation
import ReisenDomain

/// Fehler eines Laufs, die nicht aus dem Extraktor stammen.
public enum PasteImportRunError: Error, Equatable, Sendable {
    /// Ohne Modellstufe startet kein Lauf; die Stufe wählt der Resolver vorher.
    case modelUnavailable
}

/// Ein Paste-Import-Lauf: Quelle prüfen, **einmal** extrahieren, Kandidaten bauen.
///
/// Die Modellstufe kommt aus `PasteImportModelResolver` vor dem Lauf. Schlägt die Extraktion fehl,
/// endet der Lauf mit genau diesem Fehler — kein zweiter Extract mit einer anderen Stufe.
public enum PasteImportRun {
    public static func run(
        source: PasteImportSource,
        kind: PasteImportModelKind,
        extractor: PasteImportExtracting,
        existing: [Booking],
        calendar: Calendar = .current,
        normalizer: BookingTimeNormalizer = BookingTimeNormalizer()
    ) async throws -> [PasteImportCandidate] {
        guard kind != .unavailable else { throw PasteImportRunError.modelUnavailable }
        let validated = try source.validated()
        let extractions = try await extractor.extract(from: validated)
        return PasteImportPipeline.candidates(
            from: extractions,
            existing: existing,
            calendar: calendar,
            normalizer: normalizer
        )
    }
}
