import Foundation
import ReisenDomain

/// Fehler des Paste-Import-Adapters. Keine stillen Ersatzwerte: jede Ursache ist unterscheidbar.
public enum PasteImportAdapterError: Error, Equatable, Sendable {
    /// Es ist kein Modell gewählt oder verfügbar; der Lauf darf nicht starten.
    case unavailable
    /// Die Quelle liefert nichts, was an ein Modell gehen könnte (z. B. PDF ohne Seiten).
    case unreadableSource
    /// Bild-Bytes und `CGImage` lassen sich nicht ineinander überführen.
    case imageConversionFailed
    /// Das laufende System kennt die Bild-Anhänge der Foundation Models noch nicht.
    case imageInputUnsupported
}

extension PasteImportAdapterError: PasteImportFailureClassifying {
    public var pasteImportFailure: PasteImportFailure {
        switch self {
        case .unavailable:
            return .modelUnavailable
        case .unreadableSource, .imageConversionFailed:
            return .source
        case .imageInputUnsupported:
            return .imageUnsupported
        }
    }
}
