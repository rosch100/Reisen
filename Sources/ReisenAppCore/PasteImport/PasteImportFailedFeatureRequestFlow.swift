import Foundation
import Observation
import ReisenDomain

public enum PasteImportFailedFeatureRequestPhase: Equatable, Sendable {
    case idle
    case offering
    case confirming
    case submitting
    case succeeded(URL)
    case submitFailed(String)
}

@MainActor
@Observable
public final class PasteImportFailedFeatureRequestFlow {
    public private(set) var phase: PasteImportFailedFeatureRequestPhase = .idle
    public private(set) var canOffer = false
    private var afterCancel: PasteImportFailedFeatureRequestPhase = .idle

    public init() {}

    public func reset() {
        phase = .idle
        canOffer = false
        afterCancel = .idle
    }

    public func noteEmptyCandidates() {
        canOffer = true
        phase = .offering
        afterCancel = .offering
    }

    public func noteModelFailure() {
        canOffer = true
        phase = .idle
        afterCancel = .idle
    }

    public func offer() {
        guard canOffer else { return }
        switch phase {
        case .offering, .idle, .submitFailed:
            phase = .confirming
        case .confirming, .submitting, .succeeded:
            break
        }
    }

    public func cancelOffer() {
        guard phase == .confirming else { return }
        phase = afterCancel
    }

    public func acknowledgeSubmitFailure() {
        guard case .submitFailed = phase else { return }
        phase = afterCancel
    }

    public func confirm(
        source: PasteImportSource,
        reason: PasteImportFailedRecognitionReason,
        reporter: GitHubIssueReporter,
        reporterGitHubUsername: String?
    ) async {
        guard phase == .confirming else { return }
        phase = .submitting
        do {
            let created = try await PasteImportFailedFeatureRequest.submit(
                source: source,
                reason: reason,
                reporter: reporter,
                reporterGitHubUsername: reporterGitHubUsername
            )
            guard phase == .submitting else { return }
            canOffer = false
            phase = .succeeded(created.htmlURL)
        } catch {
            guard phase == .submitting else { return }
            phase = .submitFailed(error.localizedDescription)
        }
    }
}
