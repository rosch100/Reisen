import Foundation

/// Ergebnis einer Drop-/„Öffnen mit“-Entscheidung.
public enum PasteImportDropAction: Equatable, Sendable {
    /// Die erste akzeptierte Datei starten.
    case start
    /// Session ist schon aktiv — Drop nicht übernehmen.
    case ignore
    /// URLs kamen an, aber keine war als Quelle nutzbar.
    case fail
}

/// Entscheidet, ob Drop/Dock/„Öffnen mit“ einen neuen Lauf starten darf.
///
/// Ein laufender Import oder eine offene Editor-Warteschlange darf nicht durch einen zweiten
/// Datei-Einstieg überschrieben werden — anders als Toolbar/Menü, die bewusst neu starten.
public enum PasteImportDropCoordinator {
    /// - Parameters:
    ///   - offeredURLCount: Anzahl der angelieferten URLs (auch ungeeignete).
    ///   - acceptedFileCount: Anzahl der URLs, die als Paste-Import-Quelle gelten.
    ///   - isSessionActive: Lauf, Meldung oder Editor-Warteschlange ist offen.
    public static func action(
        offeredURLCount: Int,
        acceptedFileCount: Int,
        isSessionActive: Bool
    ) -> PasteImportDropAction {
        guard offeredURLCount > 0 else { return .ignore }
        if isSessionActive { return .ignore }
        if acceptedFileCount > 0 { return .start }
        return .fail
    }
}
