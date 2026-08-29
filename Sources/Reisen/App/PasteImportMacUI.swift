import AppKit
import Foundation
import ReisenDomain

/// Quellen des macOS-Einstiegs: Zwischenablage und Dateiauswahl.
enum PasteImportMacSource {
    /// `nil`, wenn die Zwischenablage nichts Verwertbares enthält — kein Ersatzinhalt.
    static func fromPasteboard(_ pasteboard: NSPasteboard = .general) -> PasteImportSource? {
        if let pdf = pasteboard.data(forType: .pdf) { return .pdf(pdf) }
        if let png = pasteboard.data(forType: .png) { return .image(png) }
        if let tiff = pasteboard.data(forType: .tiff) { return .image(tiff) }
        if let text = pasteboard.string(forType: .string) { return .text(text) }
        return nil
    }

    /// `nil`, wenn der Nutzer die Auswahl abbricht.
    ///
    /// `begin()` statt `runModal()`: ein Menübefehl darf kein geschachteltes Modal starten,
    /// sonst erscheint der Dialog nicht.
    @MainActor
    static func fromOpenPanel() async throws -> PasteImportSource? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = PasteImportFileSource.allowedContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        let response = await panel.begin()
        guard response == .OK, let url = panel.url else { return nil }
        return try PasteImportFileSource.source(from: url)
    }
}
