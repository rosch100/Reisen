import Foundation

public enum PasteImportSourceError: Error, Equatable, Sendable {
    case empty
}

public enum PasteImportSource: Equatable, Sendable {
    case text(String)
    case image(Data)
    case pdf(Data)

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

    public var payloadData: Data { mailAttachment.data }
    public var kindName: String { mailAttachment.kindName }
    public var attachmentFileName: String { mailAttachment.fileName }
    public var attachmentMimeType: String { mailAttachment.mimeType }

    private var mailAttachment: (kindName: String, fileName: String, mimeType: String, data: Data) {
        switch self {
        case .text(let text):
            (kindName: "text", fileName: "paste.txt", mimeType: "text/plain", data: Data(text.utf8))
        case .image(let data):
            (kindName: "image", fileName: "paste-image.bin", mimeType: "application/octet-stream", data: data)
        case .pdf(let data):
            (kindName: "pdf", fileName: "paste.pdf", mimeType: "application/pdf", data: data)
        }
    }
}
