import UIKit
import UniformTypeIdentifiers
import ReisenDomain

/// Fehler der Share-Extension; die Texte kommen aus dem Katalog, nicht aus einer zweiten Formulierung.
enum PasteImportShareError: LocalizedError {
    /// Das geteilte Element ist weder Text noch Bild noch PDF.
    case unreadableSource
    /// Die Bytes ließen sich nicht in die App Group schreiben.
    case handoffFailed

    var errorDescription: String? {
        switch self {
        case .unreadableSource:
            return L10n.string(.pasteImportErrorSource)
        case .handoffFailed:
            return L10n.string(.pasteImportErrorHandoff)
        }
    }
}

/// „In Reisen öffnen“: legt das geteilte Material in die App Group und übergibt an die App.
///
/// Kein SwiftData und kein Modell-Lauf in der Extension — nur Bytes schreiben. Der Lauf startet in
/// der App, wenn sie `reisen://paste-import` erhält oder die liegende Übergabe beim Aktivieren findet.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        Task { await handOff() }
    }

    private func handOff() async {
        guard let extensionContext else { return }
        do {
            let source = try await Self.source(from: extensionContext.inputItems)
            try PasteImportHandoff.write(source)
            // iOS öffnet die App aus einer Share-Extension nicht garantiert; die App holt die
            // Übergabe beim nächsten Aktivieren nach, deshalb ist ein `false` hier kein Fehler.
            _ = await extensionContext.open(PasteImportHandoff.url)
            extensionContext.completeRequest(returningItems: [])
        } catch let error as PasteImportShareError {
            extensionContext.cancelRequest(withError: error)
        } catch {
            extensionContext.cancelRequest(withError: PasteImportShareError.handoffFailed)
        }
    }

    /// PDF vor Bild vor Text vor Datei-URL — über **alle** Anhänge, nicht nur den ersten Provider.
    private static func source(from items: [Any]) async throws -> PasteImportSource {
        let providers = items.compactMap { $0 as? NSExtensionItem }.flatMap { $0.attachments ?? [] }
        if let source = try await firstSource(in: providers, conformingTo: .pdf, as: { .pdf($0) }) {
            return source
        }
        if let source = try await firstSource(in: providers, conformingTo: .image, as: { .image($0) }) {
            return source
        }
        for provider in providers {
            if let identifier = identifier(in: provider, conformingTo: .plainText) {
                let payload = try await data(from: provider, typeIdentifier: identifier)
                guard let text = String(data: payload, encoding: .utf8) else {
                    throw PasteImportShareError.unreadableSource
                }
                return .text(text)
            }
        }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            return try await source(fromFileURLProvider: provider)
        }
        throw PasteImportShareError.unreadableSource
    }

    /// Liest die Datei, räumt eigene Temp-Kopien auf; fehlgeschlagenes Aufräumen → `handoffFailed`.
    private static func source(fromFileURLProvider provider: NSItemProvider) async throws -> PasteImportSource {
        let url = try await fileURL(from: provider)
        let source: PasteImportSource
        do {
            source = try PasteImportFileSource.source(from: url)
        } catch let error as PasteImportShareError {
            try? removeTemporaryCopyIfNeeded(url)
            throw error
        } catch {
            try? removeTemporaryCopyIfNeeded(url)
            throw PasteImportShareError.unreadableSource
        }
        do {
            try removeTemporaryCopyIfNeeded(url)
        } catch {
            throw PasteImportShareError.handoffFailed
        }
        return source
    }

    /// Nur eigene Kopien unter `temporaryDirectory` löschen — nicht Security-Scoped URLs des Systems.
    ///
    /// Scheitert das Löschen einer eigenen Temp-Kopie, bleibt Buchungsinhalt liegen — deshalb Fehler
    /// statt `try?`, nachdem die Bytes bereits gelesen wurden.
    private static func removeTemporaryCopyIfNeeded(_ url: URL) throws {
        let temporary = FileManager.default.temporaryDirectory.standardizedFileURL.path
        guard url.standardizedFileURL.path.hasPrefix(temporary) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private static func firstSource(
        in providers: [NSItemProvider],
        conformingTo type: UTType,
        as wrap: (Data) -> PasteImportSource
    ) async throws -> PasteImportSource? {
        for provider in providers {
            if let identifier = identifier(in: provider, conformingTo: type) {
                return wrap(try await data(from: provider, typeIdentifier: identifier))
            }
        }
        return nil
    }

    /// Zuerst File-Representation (Kopie im Callback lesen), dann `URL`/`Data`-Objekt.
    private static func fileURL(from provider: NSItemProvider) async throws -> URL {
        if let url = try? await fileURLFromRepresentation(provider) {
            return url
        }
        return try await fileURLFromObject(provider)
    }

    private static func fileURLFromRepresentation(_ provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier) {
                url,
                error in
                guard let url else {
                    continuation.resume(throwing: error ?? PasteImportShareError.unreadableSource)
                    return
                }
                // Apple löscht die Temp-Kopie nach dem Callback — Bytes sofort lesen und lokal halten.
                let local = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension.isEmpty ? "bin" : url.pathExtension)
                do {
                    if FileManager.default.fileExists(atPath: local.path) {
                        try FileManager.default.removeItem(at: local)
                    }
                    try FileManager.default.copyItem(at: url, to: local)
                    continuation.resume(returning: local)
                } catch {
                    continuation.resume(throwing: PasteImportShareError.unreadableSource)
                }
            }
        }
    }

    private static func fileURLFromObject(_ provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { object, error in
                if let url = PasteImportLoadedFileURL.url(fromLoadedItem: object) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: error ?? PasteImportShareError.unreadableSource)
                }
            }
        }
    }

    private static func identifier(in provider: NSItemProvider, conformingTo type: UTType) -> String? {
        provider.registeredTypeIdentifiers.first { identifier in
            UTType(identifier)?.conforms(to: type) == true
        }
    }

    private static func data(
        from provider: NSItemProvider,
        typeIdentifier: String
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? PasteImportShareError.unreadableSource)
                }
            }
        }
    }
}
