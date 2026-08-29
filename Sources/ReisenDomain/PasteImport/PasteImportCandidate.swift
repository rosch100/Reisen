/// Ein Paste-Import-Draft samt Abgleichergebnis gegen den Bestand.
public struct PasteImportCandidate: Equatable, Sendable {
    public var draft: PasteImportDraft
    public var match: PasteImportMatch

    /// Genau ein Bestandstreffer: die Buchung wird ergänzt statt neu angelegt.
    public var isErgaenzen: Bool {
        uniqueMatchedBooking != nil
    }

    /// Bestandsbuchung bei eindeutigem Match — sonst `nil` (kein Ergänzen).
    public var uniqueMatchedBooking: Booking? {
        if case .unique(let booking) = match { return booking }
        return nil
    }

    /// Mehrere Bestandstreffer: die Zuordnung ist offen und braucht einen Hinweis in der UI.
    public var showsAmbiguousHint: Bool { match == .ambiguous }

    public init(draft: PasteImportDraft, match: PasteImportMatch) {
        self.draft = draft
        self.match = match
    }
}
