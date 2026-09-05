import Foundation

/// Copy-Verhalten für Info-Feldwerte (SSOT im Feldkatalog).
public enum FieldCopyKind: Sendable, Equatable {
    /// Selektion + Kontextmenü „Kopieren“ (ganzer Wert); kein Tap-to-Copy.
    case standard
    /// Tap/Klick kopiert den ganzen Wert (Kennungen: Buchungsnummer/PNR).
    case identifier
}
