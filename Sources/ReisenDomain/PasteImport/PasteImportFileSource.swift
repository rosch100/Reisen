import Foundation
import UniformTypeIdentifiers

/// Die Datei liegt vor, ist aber kein PDF, Bild oder UTF-8-Text — oder nicht lesbar.
public enum PasteImportFileSourceError: Error, Equatable, Sendable {
    case unreadable
    case unsupportedType
}

extension PasteImportFileSourceError: PasteImportFailureClassifying {
    public var pasteImportFailure: PasteImportFailure { .source }
}

/// Datei → `PasteImportSource`. Einzige Typ-Liste für Dialog, Drop, „Öffnen mit“ und Share.
public enum PasteImportFileSource {
    public static let allowedContentTypes: [UTType] = [.pdf, .image, .plainText]

    public static var importedTypeIdentifiers: [String] {
        allowedContentTypes.map(\.identifier)
    }

    /// Dateien, die der Import annimmt — Verzeichnisse und fremde Typen entfallen.
    public static func acceptedFiles(in urls: [URL]) -> [URL] {
        urls.filter { url in
            let didStartAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess { url.stopAccessingSecurityScopedResource() }
            }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else {
                return false
            }
            return isAllowed(url)
        }
    }

    public static func source(from url: URL) throws -> PasteImportSource {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess { url.stopAccessingSecurityScopedResource() }
        }
        let data = try Data(contentsOf: url)
        guard let type = contentType(of: url) else {
            throw PasteImportFileSourceError.unsupportedType
        }
        if type.conforms(to: .pdf) { return .pdf(data) }
        if type.conforms(to: .image) { return .image(data) }
        guard type.conforms(to: .plainText) else {
            throw PasteImportFileSourceError.unsupportedType
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw PasteImportFileSourceError.unreadable
        }
        return .text(text)
    }

    public static func isAllowed(_ url: URL) -> Bool {
        guard let type = contentType(of: url) else { return false }
        return allowedContentTypes.contains { type.conforms(to: $0) }
    }

    /// Share-Sheet / „Senden an“: Files liefert oft nur `public.file-url`, keinen Inhalts-UTI.
    public static func acceptsShareIdentifiers(_ identifiers: [String]) -> Bool {
        identifiers.contains { identifier in
            guard let type = UTType(identifier) else { return false }
            if allowedContentTypes.contains(where: { type.conforms(to: $0) }) { return true }
            return type.conforms(to: .fileURL)
        }
    }

    private static func contentType(of url: URL) -> UTType? {
        (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
            ?? UTType(filenameExtension: url.pathExtension)
    }
}
