import Foundation
import ReisenData
import ReisenDomain

/// Füllt den Buchungseditor aus einem Paste-Import-Kandidaten vor.
///
/// Zwei Fälle, ein Merger: ohne Bestandstreffer entsteht eine neue Buchung allein aus dem Draft,
/// mit genau einem Treffer werden nur die Lücken der bestehenden Buchung gefüllt
/// (`PasteImportMerger.fillingGaps`). Die bestehende `SDBooking` wird dabei nicht verändert —
/// gespeichert wird erst, wenn der Nutzer den Editor bestätigt.
public enum PasteImportEditorPrefill {
    /// Anders als `BookingEditorDraft.createDefault` braucht der Prefill keinen Reise-Zeitraum als
    /// Ausgangspunkt: `PasteImportFilter` verwirft Extractions ohne Start, Beginn und Ende kommen
    /// deshalb immer aus dem Kandidaten.
    public static func draft(
        for candidate: PasteImportCandidate,
        existing: SDBooking?
    ) -> BookingEditorDraft {
        guard candidate.isErgaenzen, let existing else {
            return newBooking(from: candidate.draft)
        }
        let merged = PasteImportMerger.fillingGaps(
            on: DomainMapper.booking(from: existing),
            from: candidate.draft
        )
        return BookingEditorDraft.fromDomain(merged)
    }

    /// Identität, Typ und Zeitraum stellt der Draft, alles Weitere füllt derselbe Merger wie beim
    /// Ergänzen. Kein `createDefault`, sonst stünden erfundene Hotel-Minuten im Editor.
    private static func newBooking(from draft: PasteImportDraft) -> BookingEditorDraft {
        let base = Booking(
            provider: .manual,
            bookingType: draft.bookingType,
            externalUrl: draft.externalUrl,
            startAt: draft.startAt,
            endAt: draft.endAt,
            status: draft.status
        )
        var editorDraft = BookingEditorDraft.fromDomain(
            PasteImportMerger.fillingGaps(on: base, from: draft)
        )
        editorDraft.bookingID = nil
        return editorDraft
    }
}
