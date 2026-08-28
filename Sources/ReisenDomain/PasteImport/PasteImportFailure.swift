import Foundation

/// Fehlerklassen des Paste-Imports, wie sie dem Nutzer gemeldet werden.
public enum PasteImportFailure: Equatable, Sendable {
    /// Die Quelle liefert nichts Verwertbares.
    case source
    /// Es gibt keine nutzbare Modellstufe.
    case modelUnavailable
    /// Das laufende System kennt die Bild-Anhänge der Foundation Models nicht.
    case imageUnsupported
    /// Der Modelllauf selbst ist fehlgeschlagen.
    case model

    public var messageKey: L10nKey {
        switch self {
        case .source:
            return .pasteImportErrorSource
        case .modelUnavailable:
            return .pasteImportUnavailable
        case .imageUnsupported:
            return .pasteImportErrorImageUnsupported
        case .model:
            return .pasteImportErrorModel
        }
    }
}

/// Fehler, die ihre eigene Paste-Import-Fehlerklasse kennen.
///
/// Die Konformität liegt jeweils beim Modul, das den Fehler definiert; die Zuordnung zum Text
/// steht nur in `PasteImportFailureMessage`.
public protocol PasteImportFailureClassifying: Error {
    var pasteImportFailure: PasteImportFailure { get }
}

extension PasteImportSourceError: PasteImportFailureClassifying {
    public var pasteImportFailure: PasteImportFailure { .source }
}

/// Meldungstext eines Paste-Import-Fehlers — eine Zuordnung für macOS und iOS.
public enum PasteImportFailureMessage {
    public static func text(for error: Error) -> String {
        L10n.string(failure(for: error).messageKey)
    }

    /// Ein nicht klassifizierter Fehler kommt aus dem Modelllauf und wird als Modellfehler gemeldet.
    public static func failure(for error: Error) -> PasteImportFailure {
        (error as? PasteImportFailureClassifying)?.pasteImportFailure ?? .model
    }
}
