/// Modell, mit dem eine Paste-Import-Extraktion ausgeführt wird.
public enum PasteImportModelKind: String, Equatable, Sendable {
    case privateCloudCompute
    case onDevice
    case unavailable

    /// Anzeigename der Stufe für den Fortschritt; `.unavailable` hat keinen, weil damit kein Lauf
    /// startet. Einzige Zuordnung Stufe → Text, wie `PasteImportFailure.messageKey`.
    public var nameKey: L10nKey? {
        switch self {
        case .privateCloudCompute:
            return .pasteImportModelPcc
        case .onDevice:
            return .pasteImportModelOnDevice
        case .unavailable:
            return nil
        }
    }
}
