import CryptoKit
import Foundation
import ReisenDomain

enum PasteImportFailedFeatureRequestCopy {
    static let titleMessage = "Paste-Import: Dokument nicht erkannt"

    static var issueTitle: String {
        GitHubIssueTitle.reportTitle(kind: .feature, message: titleMessage)
    }
}

@MainActor
public enum PasteImportFailedFeatureRequest {
    public static func submit(
        source: PasteImportSource,
        reason: PasteImportFailedRecognitionReason,
        reporter: GitHubIssueReporter,
        reporterGitHubUsername: String?
    ) async throws -> PasteImportFailedFeatureRequestOutcome {
        let hash = sha256Hex(of: source)
        let lines = [
            PasteImportFailedFeatureRequestCopy.titleMessage,
            "Grund: \(reason)",
            "Quelle: \(source.kindName)",
            "reisen-source-sha256: \(hash)",
            "Dokument: per E-Mail (nicht an GitHub).",
        ]
        let issue = try await reporter.report(
            kind: .feature,
            message: lines.joined(separator: "\n"),
            providerID: nil,
            titleOverride: PasteImportFailedFeatureRequestCopy.issueTitle,
            reporterGitHubUsername: reporterGitHubUsername,
            fingerprintMessage: "paste-import-failed\n\(hash)"
        )
        return PasteImportFailedFeatureRequestOutcome(
            issue: issue,
            mail: PasteImportFailedMailDraft.make(source: source, issueURL: issue.htmlURL)
        )
    }

    private static func sha256Hex(of source: PasteImportSource) -> String {
        SHA256.hash(data: source.payloadData).map { String(format: "%02x", $0) }.joined()
    }
}
