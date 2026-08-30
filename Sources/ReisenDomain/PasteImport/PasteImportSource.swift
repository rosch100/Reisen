import Foundation
import ImageIO
import UniformTypeIdentifiers

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
        case .image(let data):
            Self.imageMailAttachment(for: data)
        case .pdf:
            (fileName: "paste.pdf", mimeType: "application/pdf")
        }
    }

    /// Magic-Bytes zuerst, sonst ImageIO/UTType — kein generisches `.bin` für bekannte Formate.
    static func imageMailAttachment(for data: Data) -> (fileName: String, mimeType: String) {
        if matches(data, prefix: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return (fileName: "paste-image.png", mimeType: "image/png")
        }
        if matches(data, prefix: [0xFF, 0xD8, 0xFF]) {
            return (fileName: "paste-image.jpg", mimeType: "image/jpeg")
        }
        if matches(data, prefix: [0x47, 0x49, 0x46, 0x38]) {
            return (fileName: "paste-image.gif", mimeType: "image/gif")
        }
        if isWebP(data) {
            return (fileName: "paste-image.webp", mimeType: "image/webp")
        }
        if isHEICFamily(data) {
            return (fileName: "paste-image.heic", mimeType: "image/heic")
        }
        if let type = imageContentType(for: data),
           let mime = type.preferredMIMEType,
           let ext = type.preferredFilenameExtension {
            return (fileName: "paste-image.\(ext)", mimeType: mime)
        }
        return (fileName: "paste-image.bin", mimeType: "application/octet-stream")
    }

    private static func matches(_ data: Data, prefix: [UInt8]) -> Bool {
        guard data.count >= prefix.count else { return false }
        return data.prefix(prefix.count).elementsEqual(prefix)
    }

    private static func isWebP(_ data: Data) -> Bool {
        guard data.count >= 12 else { return false }
        return data[0..<4] == Data([0x52, 0x49, 0x46, 0x46])
            && data[8..<12] == Data([0x57, 0x45, 0x42, 0x50])
    }

    private static func isHEICFamily(_ data: Data) -> Bool {
        guard data.count >= 12, data[4..<8] == Data("ftyp".utf8) else { return false }
        let brand = String(data: data[8..<12], encoding: .ascii) ?? ""
        let brands = ["heic", "heix", "hevc", "hevx", "mif1", "msf1"]
        return brands.contains(where: { brand.hasPrefix($0) })
    }

    private static func imageContentType(for data: Data) -> UTType? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let typeID = CGImageSourceGetType(source) as String? else {
            return nil
        }
        return UTType(typeID)
    }
}
