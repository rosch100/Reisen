/// Ergebnis einer Extraktion: Buchungen plus Hinweis, ob der Quelltext gekürzt wurde.
public struct PasteImportExtractionResult: Equatable, Sendable {
    public var extractions: [PasteImportExtraction]
    /// `true`, wenn Text wegen des Prompt-Budgets gekürzt wurde — UI soll warnen.
    public var sourceWasTruncated: Bool

    public init(extractions: [PasteImportExtraction], sourceWasTruncated: Bool = false) {
        self.extractions = extractions
        self.sourceWasTruncated = sourceWasTruncated
    }
}

/// Port für die Extraktion von Buchungsdaten aus einer eingefügten Quelle.
public protocol PasteImportExtracting: Sendable {
    func extract(from source: PasteImportSource) async throws -> PasteImportExtractionResult
}
