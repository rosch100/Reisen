import Foundation

/// Grenzen für App-eigene Temp-Kopien (Share-Extension, PNG-Fallback).
public enum PasteImportTemporaryPath {
    /// Segment-sichere Prüfung: Sibling-Pfade wie `…/T2` matchen nicht Prefixe von `…/T`.
    public static func contains(
        _ url: URL,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) -> Bool {
        let temporary = temporaryDirectory.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return PathPrefix.isUnder(path, root: temporary)
    }
}
