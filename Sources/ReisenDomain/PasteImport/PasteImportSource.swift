import Foundation

public enum PasteImportSourceError: Error, Equatable, Sendable {
    case empty
    /// Text-Payload ist kein UTF-8, oder die Handoff-Art ist unbekannt.
    case unreadableHandoff
}

public enum PasteImportSource: Equatable, Sendable {
    case text(String)
    case image(Data)
    case pdf(Data)

    /// Art der Bytes — SSOT für Logs, Feature-Requests und Handoff-Meta (`text`/`image`/`pdf`).
    public enum Kind: String, Codable, Equatable, Sendable {
        case text
        case image
        case pdf
    }

    public var kind: Kind {
        switch self {
        case .text:
            .text
        case .image:
            .image
        case .pdf:
            .pdf
        }
    }

    /// Bytes für Fingerprints (SHA) und Handoff-Payload — Text als UTF-8, sonst Rohdaten.
    public var fingerprintData: Data {
        switch self {
        case .text(let text):
            Data(text.utf8)
        case .image(let bytes), .pdf(let bytes):
            bytes
        }
    }

    /// Rekonstruiert die Quelle aus Handoff-Meta + Payload-Bytes.
    public static func fromHandoff(kind: Kind, payload: Data) throws -> PasteImportSource {
        switch kind {
        case .text:
            guard let text = String(data: payload, encoding: .utf8) else {
                throw PasteImportSourceError.unreadableHandoff
            }
            return .text(text)
        case .image:
            return .image(payload)
        case .pdf:
            return .pdf(payload)
        }
    }

    public func validated() throws -> PasteImportSource {
        switch self {
        case .text(let raw):
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw PasteImportSourceError.empty }
            return .text(trimmed)
        case .image(let data), .pdf(let data):
            guard !data.isEmpty else { throw PasteImportSourceError.empty }
            return self
        }
    }

    public var payloadData: Data { fingerprintData }
    public var kindName: String { kind.rawValue }
    public var attachmentFileName: String { mailAttachment.fileName }
    public var attachmentMimeType: String { mailAttachment.mimeType }

    private var mailAttachment: (fileName: String, mimeType: String) {
        switch self {
        case .text:
            (fileName: "paste.txt", mimeType: "text/plain")
        case .image:
            (fileName: "paste-image.bin", mimeType: "application/octet-stream")
        case .pdf:
            (fileName: "paste.pdf", mimeType: "application/pdf")
        }
    }
}
