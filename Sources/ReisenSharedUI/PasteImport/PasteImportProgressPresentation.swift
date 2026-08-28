import Foundation
import ReisenDomain

/// Fortschritt eines Paste-Import-Laufs: was gerade passiert und mit welcher Modellstufe.
///
/// Die Stufe gehört sichtbar ins Sheet: nur so sieht der Nutzer während des Laufs, ob das
/// eingefügte Material das Gerät verlässt.
public struct PasteImportProgressPresentation: Equatable, Sendable {
    public let title: String
    /// `nil` nur für `.unavailable` — mit dieser Stufe startet kein Lauf.
    public let modelName: String?

    public init(kind: PasteImportModelKind) {
        title = L10n.string(.pasteImportProgress)
        modelName = kind.nameKey.map(L10n.string)
    }
}
