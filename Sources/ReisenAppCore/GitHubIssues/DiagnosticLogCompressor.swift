import Foundation
import ReisenDomain

enum DiagnosticLogCompressorError: Error {
    case invalidBase64
    case invalidUTF8
}

enum DiagnosticLogCompressor {
    static func zlibBase64(_ text: String) throws -> String {
        let compressed = try (Data(text.utf8) as NSData).compressed(using: .zlib) as Data
        return compressed.base64EncodedString()
    }

    static func decodeUTF8(fromZlibBase64 encoded: String) throws -> String {
        guard let data = Data(base64Encoded: encoded) else {
            throw DiagnosticLogCompressorError.invalidBase64
        }
        let raw = try (data as NSData).decompressed(using: .zlib) as Data
        guard let text = String(data: raw, encoding: .utf8) else {
            throw DiagnosticLogCompressorError.invalidUTF8
        }
        return text
    }

    static func preview(from text: String, lastLineCount: Int) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        return lines.suffix(lastLineCount).joined(separator: "\n")
    }
}

enum DiagnosticLogAttachment: Equatable, Sendable {
    case missing
    case empty
    case unreadable(String)
    case compressionFailed(preview: String)
    case attached(
        preview: String,
        zlibBase64: String,
        rawByteCount: Int,
        fileByteCount: Int,
        truncated: Bool
    )

    static let attachMaxRawBytes = 16_384
    static let previewLineCount = 12
    static let commentPreviewLineCount = 5
    static let missingStatus = "Sync-Log: nicht vorhanden"
    static let emptyStatus = "Sync-Log: leer"
    private static let logSectionHeading = GitHubIssueMarkdown.sectionHeading("Sync-Log")
    private static var previewHeading: String {
        "### Vorschau (letzte \(previewLineCount) Zeilen, geschwärzt)"
    }

    static func unreadableStatus(_ detail: String) -> String {
        "Sync-Log: nicht lesbar\n\(SecretRedactor.redact(detail))"
    }

    static func makeAttached(
        redactedTail: String,
        fileByteCount: Int,
        truncated: Bool
    ) -> DiagnosticLogAttachment {
        let preview = DiagnosticLogCompressor.preview(
            from: redactedTail,
            lastLineCount: previewLineCount
        )
        do {
            let blob = try DiagnosticLogCompressor.zlibBase64(redactedTail)
            return .attached(
                preview: preview,
                zlibBase64: blob,
                rawByteCount: redactedTail.utf8.count,
                fileByteCount: fileByteCount,
                truncated: truncated
            )
        } catch {
            return .compressionFailed(preview: preview)
        }
    }

    func markdownSection(includeCompressedLog: Bool) -> String {
        switch self {
        case .missing:
            return Self.statusSection(Self.missingStatus)
        case .empty:
            return Self.statusSection(Self.emptyStatus)
        case .unreadable(let detail):
            return Self.statusSection(Self.unreadableStatus(detail))
        case .compressionFailed(let preview):
            return """

            \(Self.logSectionHeading)
            \(Self.previewHeading)
            \(GitHubIssueMarkdown.fence(preview))
            Kompression fehlgeschlagen
            """
        case .attached(let preview, let blob, let raw, let file, let truncated):
            var text = """

            \(Self.logSectionHeading)
            | Feld | Wert |
            | --- | --- |
            | Dateigröße | \(file) B |
            | Anhang roh | \(raw) B |
            | truncated | \(truncated ? "ja" : "nein") |

            \(Self.previewHeading)
            \(GitHubIssueMarkdown.fence(preview))
            """
            if includeCompressedLog {
                text += """

                ### zlib+Base64
                \(GitHubIssueMarkdown.fence(blob))
                """
            }
            return text
        }
    }

    private static func statusSection(_ status: String) -> String {
        "\n\(logSectionHeading)\n\(status)\n"
    }

    func commentBlock() -> String {
        switch self {
        case .missing:
            return Self.missingStatus
        case .empty:
            return Self.emptyStatus
        case .unreadable(let detail):
            return Self.unreadableStatus(detail)
        case .attached(let preview, _, _, _, _), .compressionFailed(let preview):
            return GitHubIssueMarkdown.fence(
                DiagnosticLogCompressor.preview(
                    from: preview,
                    lastLineCount: Self.commentPreviewLineCount
                )
            )
        }
    }
}
