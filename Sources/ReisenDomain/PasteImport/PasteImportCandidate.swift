/// Ein Paste-Import-Draft samt Abgleichergebnis gegen den Bestand.
public struct PasteImportCandidate: Equatable, Sendable {
    public var draft: PasteImportDraft
    public var match: PasteImportMatch

    /// Genau ein Bestandstreffer: die Buchung wird ergänzt statt neu angelegt.
    public var isErgaenzen: Bool {
        if case .unique = match { return true }
        return false
    }

    /// Mehrere Bestandstreffer: die Zuordnung ist offen und braucht einen Hinweis in der UI.
    public var showsAmbiguousHint: Bool { match == .ambiguous }

    public init(draft: PasteImportDraft, match: PasteImportMatch) {
        self.draft = draft
        self.match = match
    }
}
