import SwiftUI
import ReisenAppCore
import ReisenDomain

/// Melde-Button für öffentliche GitHub-Issues (Token-API oder vorausgefüllte URL mit eigenem Konto).
public struct PublicGitHubIssueReportActions: View {
    private enum ButtonLabel {
        static let directReport = "Als öffentliches Issue melden"
        static let openInGitHub = "In GitHub veröffentlichen…"
    }

    public let kind: GitHubIssueKind
    public let titleOverride: String?
    public let message: String
    public let providerID: ProviderID?
    public var reportedURL: URL?
    public var reportError: String?
    public var didPostUpdate: Bool
    public var onReported: (() -> Void)?

    @Environment(\.openURL) private var openURL
    @AppStorage(AppSettingsKeys.feedbackGitHubUsername) private var feedbackGitHubUsername = ""

    @State private var localURL: URL?
    @State private var localError: String?
    @State private var localDidPostUpdate = true
    @State private var isReporting = false

    private var submissionMode: GitHubIssueSubmissionMode {
        GitHubIssueSubmissionMode.resolve(tokenEmbedded: GitHubIssueToken.isEmbedded)
    }

    private var reportButtonLabel: String {
        submissionMode == .embeddedToken ? ButtonLabel.directReport : ButtonLabel.openInGitHub
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

    private var resolvedTitle: String {
        titleOverride ?? GitHubIssueTitle.reportTitle(kind: kind, message: trimmedMessage)
    }

    private var canReport: Bool {
        !trimmedMessage.isEmpty
    }

    public init(
        kind: GitHubIssueKind = .error,
        titleOverride: String? = nil,
        message: String,
        providerID: ProviderID? = nil,
        reportedURL: URL? = nil,
        reportError: String? = nil,
        didPostUpdate: Bool = true,
        onReported: (() -> Void)? = nil
    ) {
        self.kind = kind
        self.titleOverride = titleOverride
        self.message = message
        self.providerID = providerID
        self.reportedURL = reportedURL
        self.reportError = reportError
        self.didPostUpdate = didPostUpdate
        self.onReported = onReported
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if submissionMode == .embeddedToken || displayError != nil {
                PublicGitHubIssueLink(
                    url: submissionMode == .embeddedToken ? displayURL : nil,
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

        if let validationError = GitHubUsername.validationError(for: feedbackGitHubUsername) {
            localError = validationError
            return
        }

        let normalizedGitHub = GitHubUsername.normalized(feedbackGitHubUsername)
        let githubForOrigin = normalizedGitHub.isEmpty ? nil : normalizedGitHub

        switch submissionMode {
        case .openInGitHub:
            guard let url = GitHubIssueNewIssueURL.compose(
                kind: kind,
                message: trimmedMessage,
                providerID: providerID,
                githubUsername: githubForOrigin,
                titleOverride: titleOverride
            ) else {
                localError = GitHubIssueNewIssueURL.composeFailureMessage
                return
            }
            openURL(url)
            onReported?()

        case .embeddedToken:
            isReporting = true
            Task { @MainActor in
                defer { isReporting = false }
                do {
                    let created = try await GitHubIssueReporter.shared.report(
                        kind: kind,
                        message: trimmedMessage,
                        providerID: providerID,
                        titleOverride: titleOverride,
                        reporterGitHubUsername: githubForOrigin
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
}

public extension PublicGitHubIssueReportActions {
    init(
        syncError errorMessage: String,
        providerID: ProviderID?,
        store: SyncStore?
    ) {
        self.init(
            message: errorMessage,
            providerID: providerID,
            reportedURL: store?.lastPublicIssueURL,
            reportError: store?.issueReportErrorMessage,
            didPostUpdate: store?.lastPublicIssueDidPostUpdate ?? true
        )
    }

    init(storeLoadFailureMessage message: String) {
        self.init(
            titleOverride: GitHubIssueTitle.storeLoadFailure,
            message: message
        )
    }

    init(feedbackMessage: String, onReported: (() -> Void)? = nil) {
        self.init(
            kind: .feedback,
            message: feedbackMessage,
            onReported: onReported
        )
    }
}
