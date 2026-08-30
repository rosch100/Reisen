import Foundation
import ReisenDomain

public struct PasteImportFailedMailDraft: Equatable, Sendable, Identifiable {
    /// SSOT mit `Scripts/ingest-gmail-feedback.py` — Ingress legt kein öffentliches Issue an.
    public static let skipIngressMarker = "reisen-paste-import-document"

    public let id: UUID
    public let to: String
    public let subject: String
    public let body: String
    public let fileName: String
    public let mimeType: String
    public let data: Data

    init(
        id: UUID = UUID(),
        to: String,
        subject: String,
        body: String,
        fileName: String,
        mimeType: String,
        data: Data
    ) {
        self.id = id
        self.to = to
        self.subject = subject
        self.body = body
        self.fileName = fileName
        self.mimeType = mimeType
        self.data = data
    }

    public static func make(source: PasteImportSource, issueURL: URL?) -> PasteImportFailedMailDraft {
        var lines = [
            Self.skipIngressMarker,
            L10n.string(.pasteImportFeatureRequestMailBody),
        ]
        if let issueURL {
            lines.append(issueURL.absoluteString)
        }
        return PasteImportFailedMailDraft(
            to: GitHubRepository.feedbackEmail,
            subject: PasteImportFailedFeatureRequest.titleOverride,
            body: lines.joined(separator: "\n"),
            fileName: source.attachmentFileName,
            mimeType: source.attachmentMimeType,
            data: source.payloadData
        )
    }

    /// RFC822 mit Textteil und Base64-Anhang — SSOT für macOS-`NSWorkspace`-Öffnen und Unit-Tests.
    public func rfc822Data() -> Data {
        let boundary = "ReisenPasteImport_\(id.uuidString.replacingOccurrences(of: "-", with: ""))"
        let safeFileName = Self.mimeSafeFileName(fileName)
        let safeMimeType = Self.mimeSafeType(mimeType)
        let encodedFileName = Self.rfc2047Encoded(safeFileName)
        let encodedSubject = Self.rfc2047Encoded(subject)
        let foldedAttachment = Self.base64Folded(data)
        let bodyCRLF = body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: "\r\n")
        let parts: [String] = [
            "To: \(to)",
            "Subject: \(encodedSubject)",
            "MIME-Version: 1.0",
            "Content-Type: multipart/mixed; boundary=\"\(boundary)\"",
            "",
            "--\(boundary)",
            "Content-Type: text/plain; charset=utf-8",
            "Content-Transfer-Encoding: 8bit",
            "",
            bodyCRLF,
            "--\(boundary)",
            "Content-Type: \(safeMimeType); name=\"\(encodedFileName)\"",
            "Content-Transfer-Encoding: base64",
            "Content-Disposition: attachment; filename=\"\(encodedFileName)\"",
            "",
            foldedAttachment,
            "--\(boundary)--",
            "",
        ]
        return Data(parts.joined(separator: "\r\n").utf8)
    }

    /// Keine CR/LF/Quotes in MIME-Parametern — sonst Header-Injection.
    static func mimeSafeFileName(_ value: String) -> String {
        let stripped = value
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? "attachment.bin" : stripped
    }

    static func mimeSafeType(_ value: String) -> String {
        let stripped = value
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let token = "[A-Za-z0-9!#$&^_.+-]+"
        guard stripped.range(of: "^\(token)/\(token)$", options: .regularExpression) != nil else {
            return "application/octet-stream"
        }
        return stripped
    }

    private static func rfc2047Encoded(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " ._-+"))
        if value.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            return value
        }
        let encoded = Data(value.utf8).base64EncodedString()
        return "=?UTF-8?B?\(encoded)?="
    }

    private static func base64Folded(_ data: Data) -> String {
        let raw = data.base64EncodedString()
        var lines: [String] = []
        var index = raw.startIndex
        while index < raw.endIndex {
            let end = raw.index(index, offsetBy: 76, limitedBy: raw.endIndex) ?? raw.endIndex
            lines.append(String(raw[index..<end]))
            index = end
        }
        return lines.joined(separator: "\r\n")
    }
}

public struct PasteImportFailedFeatureRequestOutcome: Equatable, Sendable {
    public let issue: GitHubCreatedIssue
    public let mail: PasteImportFailedMailDraft
}

public enum PasteImportFailedMailComposeFinish: Equatable, Sendable {
    case completed
    case failed(String)

    var failureMessage: String? {
        switch self {
        case .completed:
            nil
        case .failed(let message):
            message
        }
    }

    public static func fromSharingFailure(_ error: Error) -> Self {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSUserCancelledError {
            return .completed
        }
        return failedResult(message: error.localizedDescription)
    }

    public static func fromComposer(didFail: Bool, error: Error?) -> Self {
        if didFail {
            return failedResult(message: error?.localizedDescription)
        }
        if let error {
            return fromSharingFailure(error)
        }
        return .completed
    }

    private static func failedResult(message: String?) -> Self {
        let text = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty {
            return .failed(L10n.string(.pasteImportFeatureRequestMailFailed))
        }
        return .failed(text)
    }
}
