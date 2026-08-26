import SwiftUI
import ReisenAppCore
import ReisenDomain

/// Melde-Button für öffentliche GitHub-Issues (API mit Token oder vorausgefüllte URL).
public struct PublicGitHubIssueReportActions: View {
    private enum ButtonLabel {
        static let directReport = "Als öffentliches Issue melden"
        static let openInGitHub = "In GitHub veröffentlichen…"
    }

    public let kind: GitHubIssueKind
    public let issueTitle: String
    public let message: String
    public let providerID: ProviderID?
    public var reportedURL: URL?
    public var reportError: String?
    public var didPostUpdate: Bool
    public var onReported: (() -> Void)?

    @Environment(\.openURL) private var openURL

    @State private var localURL: URL?
    @State private var localError: String?
    @State private var localDidPostUpdate = true
    @State private var isReporting = false

    private var canSubmitDirectly: Bool {
        GitHubIssueToken.isEmbedded
    }

    private var reportButtonLabel: String {
        canSubmitDirectly ? ButtonLabel.directReport : ButtonLabel.openInGitHub
    }

    private var displayURL: URL? {
        reportedURL ?? localURL
    }

    private var displayError: String? {
        reportError ?? localError
    }

    private var displayDidPostUpdate: Bool {
        reportedURL != nil ? didPostUpdate : localDidPostUpdate
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canReport: Bool {
        !trimmedMessage.isEmpty
    }

    public init(
        kind: GitHubIssueKind = .error,
        issueTitle: String,
        message: String,
        providerID: ProviderID? = nil,
        reportedURL: URL? = nil,
        reportError: String? = nil,
        didPostUpdate: Bool = true,
        onReported: (() -> Void)? = nil
    ) {
        self.kind = kind
        self.issueTitle = issueTitle
        self.message = message
        self.providerID = providerID
        self.reportedURL = reportedURL
        self.reportError = reportError
        self.didPostUpdate = didPostUpdate
        self.onReported = onReported
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if canSubmitDirectly || displayError != nil {
                PublicGitHubIssueLink(
                    url: canSubmitDirectly ? displayURL : nil,
                    errorMessage: displayError,
                    didPostUpdate: displayDidPostUpdate
                )
            }

            if displayURL == nil {
                Button(reportButtonLabel) {
                    report()
                }
                .buttonStyle(.bordered)
                .disabled(isReporting || !canReport)
            }
        }
    }

    private func report() {
        guard canReport else { return }
        localError = nil
        localURL = nil

        if !canSubmitDirectly {
            guard let url = GitHubIssueNewIssueURL.compose(
                kind: kind,
                title: issueTitle,
                message: trimmedMessage,
                providerID: providerID
            ) else {
                localError = GitHubIssueNewIssueURL.composeFailureMessage
                return
            }
            openURL(url)
            onReported?()
            return
        }

        isReporting = true
        Task { @MainActor in
            defer { isReporting = false }
            do {
                let created = try await GitHubIssueReporter.shared.report(
                    kind: kind,
                    title: issueTitle,
                    message: trimmedMessage,
                    providerID: providerID
                )
                localURL = created.htmlURL
                localDidPostUpdate = created.didPostUpdate
                localError = nil
                onReported?()
            } catch {
                localError = error.localizedDescription
            }
        }
    }
}

public extension PublicGitHubIssueReportActions {
    init(
        syncError errorMessage: String,
        providerID: ProviderID?,
        store: SyncStore?
    ) {
        self.init(
            issueTitle: GitHubIssueTitle.syncErrorReport(message: errorMessage),
            message: errorMessage,
            providerID: providerID,
            reportedURL: store?.lastPublicIssueURL,
            reportError: store?.issueReportErrorMessage,
            didPostUpdate: store?.lastPublicIssueDidPostUpdate ?? true
        )
    }

    init(storeLoadFailureMessage message: String) {
        self.init(
            issueTitle: GitHubIssueTitle.storeLoadFailure,
            message: message
        )
    }

    init(feedbackMessage: String, onReported: (() -> Void)? = nil) {
        self.init(
            kind: .feedback,
            issueTitle: GitHubIssueTitle.feedbackReport(message: feedbackMessage),
            message: feedbackMessage,
            onReported: onReported
        )
    }
}
