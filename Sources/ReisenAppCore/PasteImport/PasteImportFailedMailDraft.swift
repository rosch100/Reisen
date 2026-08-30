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
