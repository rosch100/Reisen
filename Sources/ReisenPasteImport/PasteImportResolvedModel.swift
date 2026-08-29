import Foundation
import ReisenDomain

/// Modellstufe für Toolbar und Lauf — eine Auflösung, kein zweiter Pfad.
public enum PasteImportResolvedModel {
    public static func kind() -> PasteImportModelKind {
        PasteImportModelResolver.resolve(FoundationModelsPasteImportAvailability().availability())
    }
}
