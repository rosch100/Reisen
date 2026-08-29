/// Port für die Extraktion von Buchungsdaten aus einer eingefügten Quelle.
public protocol PasteImportExtracting: Sendable {
    func extract(from source: PasteImportSource) async throws -> PasteImportExtractionResult
}
