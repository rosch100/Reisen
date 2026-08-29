import Foundation
import ReisenDomain

public enum PasteImportFailedFeatureRequest {
    public static let unrecognizedDocumentMessage = "Paste-Import: Dokument nicht erkannt"

    public static let titleOverride = GitHubIssueTitle.reportTitle(
        kind: .feature,
        message: unrecognizedDocumentMessage
    )

    @MainActor
    public static func submit(
        source: PasteImportSource,
        reason: PasteImportFailedRecognitionReason,
        reporter: GitHubIssueReporter,
        reporterGitHubUsername: String?
    ) async throws -> GitHubCreatedIssue {
        let document = PasteImportFailedDocument.from(source)
        let hash = GitHubIssueFingerprint.sha256Hex(of: source.fingerprintData)
        var lines = [
            unrecognizedDocumentMessage,
            "Grund: \(reasonLabel(reason))",
            "Quelle: \(source.kind.rawValue)",
            "reisen-source-sha256: \(hash)",
        ]
        if let text = document.text {
            let rawCount = text.utf8.count
            guard rawCount <= GitHubIssueAttachmentCodec.maxSourceBytes else {
                throw GitHubIssueReporterError.attachmentTooLarge(
                    maxBytes: GitHubIssueAttachmentCodec.maxSourceBytes
                )
            }
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
}
