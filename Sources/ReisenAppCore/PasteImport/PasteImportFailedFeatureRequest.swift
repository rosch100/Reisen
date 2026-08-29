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
    ) async throws -> PasteImportFailedFeatureRequestOutcome {
        let hash = GitHubIssueFingerprint.sha256Hex(of: source.fingerprintData)
        let lines = [
            unrecognizedDocumentMessage,
            "Grund: \(reasonLabel(reason))",
            "Quelle: \(source.kind.rawValue)",
            "reisen-source-sha256: \(hash)",
            "Dokument: per E-Mail (nicht an GitHub).",
        ]
        let issue = try await reporter.report(
            kind: .feature,
            message: lines.joined(separator: "\n"),
            providerID: nil,
            titleOverride: titleOverride,
            reporterGitHubUsername: reporterGitHubUsername,
            fingerprintMessage: "paste-import-failed\n\(hash)"
        )
        return PasteImportFailedFeatureRequestOutcome(
            issue: issue,
            mail: PasteImportFailedMailDraft.make(source: source, issueURL: issue.htmlURL)
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
