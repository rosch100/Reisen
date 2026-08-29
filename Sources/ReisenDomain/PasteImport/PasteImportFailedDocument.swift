import Foundation

public struct PasteImportFailedDocument: Equatable, Sendable {
    public let fileName: String
    public let mimeType: String
    public let text: String?
    public let binary: Data?

    public static func from(_ source: PasteImportSource) -> PasteImportFailedDocument {
        switch source {
        case .text(let text):
            return PasteImportFailedDocument(
                fileName: "paste.txt",
                mimeType: "text/plain",
                text: text,
                binary: nil
            )
        case .image(let data):
            return PasteImportFailedDocument(
                fileName: "paste-image.bin",
                mimeType: "application/octet-stream",
                text: nil,
                binary: data
            )
        case .pdf(let data):
            return PasteImportFailedDocument(
                fileName: "paste.pdf",
                mimeType: "application/pdf",
                text: nil,
                binary: data
            )
        }
    }
}
