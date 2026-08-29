import Foundation

/// Wandelt das Ergebnis von `NSItemProvider.loadObject` / Bookmark-`Data` in eine Datei-URL.
///
/// Share-Provider liefern manchmal `URL`, manchmal Bookmark-`Data` — ohne diese Normalisierung
/// scheitert „Senden an“ aus der Dateien-App trotz `public.file-url`.
public enum PasteImportLoadedFileURL {
    public static func url(fromLoadedItem object: Any?) -> URL? {
        if let url = object as? URL {
            return url
        }
        if let data = object as? Data {
            var isStale = false
            if let bookmark = try? URL(
                resolvingBookmarkData: data,
                options: [.withoutUI, .withoutMounting],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return bookmark
            }
            // Nur gültige file-URL-Bytes (nicht beliebige Data als Path).
            if let url = URL(dataRepresentation: data, relativeTo: nil), url.isFileURL {
                return url
            }
        }
        return nil
    }
}
