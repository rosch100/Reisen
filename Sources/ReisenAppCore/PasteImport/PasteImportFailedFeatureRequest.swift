import CryptoKit
import Foundation
import ReisenDomain

@MainActor
public enum PasteImportFailedFeatureRequest {
    public static let titleOverride = GitHubIssueTitle.reportTitle(
        kind: .feature,
        message: "Paste-Import: Dokument nicht erkannt"
    )

    public static func submit(
        source: PasteImportSource,
        reason: PasteImportFailedRecognitionReason,
        reporter: GitHubIssueReporter,
        reporterGitHubUsername: String?
    ) async throws -> GitHubCreatedIssue {
        let document = PasteImportFailedDocument.from(source)
        let hash = sha256Hex(of: source)
        var lines = [
            "Paste-Import: Dokument nicht erkannt",
            "Grund: \(reasonLabel(reason))",
            "Quelle: \(sourceKind(source))",
            "reisen-source-sha256: \(hash)",
        ]
        if let text = document.text {
            lines.append("")
            lines.append(text)
        }
        let attachments: [GitHubIssueAttachment]
        if let binary = document.binary {
            attachments = [
                GitHubIssueAttachment(
                    fileName: document.fileName,
                    mimeType: document.mimeType,
                    data: binary
                )
            ]
        } else {
            attachments = []
        }
        return try await reporter.report(
            kind: .feature,
            message: lines.joined(separator: "\n"),
            providerID: nil,
            titleOverride: titleOverride,
            reporterGitHubUsername: reporterGitHubUsername,
            attachments: attachments,
            fingerprintMessage: "paste-import-failed\n\(hash)"
        )
    }

    private static func reasonLabel(_ reason: PasteImportFailedRecognitionReason) -> String {
        switch reason {
        case .noCandidates:
            "noCandidates"
        case .model:
            "model"
        }
    }

    private static func sourceKind(_ source: PasteImportSource) -> String {
        switch source {
        case .text:
            "text"
        case .image:
            "image"
        case .pdf:
            "pdf"
        }
    }

    private static func sha256Hex(of source: PasteImportSource) -> String {
        let data: Data
        switch source {
        case .text(let text):
            data = Data(text.utf8)
        case .image(let bytes), .pdf(let bytes):
            data = bytes
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
