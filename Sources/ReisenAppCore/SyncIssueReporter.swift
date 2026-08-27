import Foundation
import ReisenDomain

@MainActor
package final class SyncIssueReporter {
    package var onUpdate: (
        _ url: URL?,
        _ didPostUpdate: Bool,
        _ errorMessage: String?
    ) -> Void = { _, _, _ in }

    private var issueReportTask: Task<Void, Never>?

    package init() {}

    package func reset() {
        onUpdate(nil, true, nil)
    }

    package func scheduleIfNeeded(
        message: String,
        providerID: ProviderID?
    ) {
        guard GitHubIssueAutoReport.shouldReport(message: message) else { return }
        reset()
        guard GitHubIssueAutoReport.isAutomaticReportingEnabled() else { return }
        let previous = issueReportTask
        issueReportTask = Task { @MainActor [weak self] in
            await previous?.value
            guard let self else { return }
            do {
                let created = try await GitHubIssueReporter.shared.report(
                    kind: .error,
                    message: message,
                    providerID: providerID,
                    reporterGitHubUsername: AppSettingsKeys.optionalFeedbackGitHubUsername()
                )
                self.onUpdate(created.htmlURL, created.didPostUpdate, nil)
            } catch is GitHubIssueTokenError {
                return
            } catch {
                self.onUpdate(nil, true, error.localizedDescription)
            }
        }
    }

    package func scheduleIfNeeded(
        error: Error,
        providerID: ProviderID?
    ) {
        guard GitHubIssueAutoReport.shouldReport(error: error) else { return }
        scheduleIfNeeded(message: error.localizedDescription, providerID: providerID)
    }
}
