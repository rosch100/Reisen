import Foundation

extension Notification.Name {
    /// Liegt, sobald Dateien von außen (Dock, „Öffnen mit“) angeboten wurden.
    public static let pasteImportExternalFilesOffered = Notification.Name(
        "de.reisen.pasteImportExternalFilesOffered"
    )
}

/// Hält Datei-URLs, bis die UI sie abholt — Dock-Drop kann vor dem ersten Window kommen.
@MainActor
public enum PasteImportExternalFileInbox {
    private static var urls: [URL] = []

    public static func offer(_ urls: [URL]) {
        self.urls.append(contentsOf: urls)
        NotificationCenter.default.post(name: .pasteImportExternalFilesOffered, object: nil)
    }

    public static func take() -> [URL] {
        let taken = urls
        urls = []
        return taken
    }

    /// Stellt URLs wieder vorne an, wenn ein Konsum `.ignore` war (Session noch aktiv).
    public static func restore(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        self.urls = urls + self.urls
    }
}
