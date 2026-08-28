/// Modell, mit dem eine Paste-Import-Extraktion ausgeführt wird.
public enum PasteImportModelKind: String, Equatable, Sendable {
    case privateCloudCompute
    case onDevice
    case unavailable
}
