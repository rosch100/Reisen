/// Ergebnis eines Paste-Import-Laufs: Kandidaten und Truncation-Hinweis für die UI.
public struct PasteImportRunResult: Equatable, Sendable {
    public var candidates: [PasteImportCandidate]
    /// `true`, wenn der Quelltext wegen des Prompt-Budgets gekürzt wurde.
    public var sourceWasTruncated: Bool

    public init(candidates: [PasteImportCandidate], sourceWasTruncated: Bool = false) {
        self.candidates = candidates
        self.sourceWasTruncated = sourceWasTruncated
    }
}
