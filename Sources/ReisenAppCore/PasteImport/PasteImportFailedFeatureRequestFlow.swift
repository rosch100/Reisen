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

    /// Bestätigungs-Alert nur vor dem Submit — nicht währenddessen, nicht nach Erfolg/Fehler.
    public var showsConfirmAlert: Bool {
        self == .confirming
    }
}

@MainActor
@Observable
public final class PasteImportFailedFeatureRequestFlow {
    public private(set) var phase: PasteImportFailedFeatureRequestPhase = .idle
    public private(set) var canOffer = false
    public private(set) var mailDraft: PasteImportFailedMailDraft?
    public private(set) var mailComposeError: String?
    private var afterCancel: PasteImportFailedFeatureRequestPhase = .idle

    public init() {}

    public func reset() {
        phase = .idle
        canOffer = false
        afterCancel = .idle
        mailDraft = nil
        mailComposeError = nil
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

    /// Angebot nach dem Lauf: 0 Kandidaten → `noCandidates`, sonst kein Angebot.
    @discardableResult
    public func applyRunResult(_ result: PasteImportRunResult) -> PasteImportFailedRecognitionReason? {
        if PasteImportFailedRecognition.shouldOffer(candidateCount: result.candidates.count) {
            noteEmptyCandidates()
            return .noCandidates
        }
        reset()
        return nil
    }

    /// Angebot nach einem Lauf-Fehler: nur `PasteImportFailure.model`.
    @discardableResult
    public func applyRunFailure(_ failure: PasteImportFailure) -> PasteImportFailedRecognitionReason? {
        if PasteImportFailedRecognition.shouldOffer(failure: failure) {
            noteModelFailure()
            return .model
        }
        reset()
        return nil
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

    public func finishMailCompose(_ finish: PasteImportFailedMailComposeFinish) {
        mailDraft = nil
        mailComposeError = finish.failureMessage
    }

    public func acknowledgeSubmitFailure() {
        guard case .submitFailed = phase else { return }
        phase = afterCancel
    }

    public func beginSubmit() -> Bool {
        guard phase == .confirming else { return false }
        phase = .submitting
        return true
    }

    /// `true`, wenn das Host-UI das Angebot wiederherstellen soll.
    public func cancelConfirmAlert() -> Bool {
        guard phase.showsConfirmAlert else { return false }
        cancelOffer()
        return true
    }

    @discardableResult
    public func startConfirm(
        source: PasteImportSource,
        reason: PasteImportFailedRecognitionReason,
        reporter: GitHubIssueReporter,
        reporterGitHubUsername: String?
    ) -> Task<Void, Never> {
        guard beginSubmit() else {
            return Task { @MainActor in }
        }
        return Task { @MainActor in
            await confirm(
                source: source,
                reason: reason,
                reporter: reporter,
                reporterGitHubUsername: reporterGitHubUsername
            )
        }
    }

    /// Submit nur nach `beginSubmit()` / `startConfirm()` — nicht direkt aus `.confirming`.
    func confirm(
        source: PasteImportSource,
        reason: PasteImportFailedRecognitionReason,
        reporter: GitHubIssueReporter,
        reporterGitHubUsername: String?
    ) async {
        guard phase == .submitting else { return }
        do {
            let outcome = try await PasteImportFailedFeatureRequest.submit(
                source: source,
                reason: reason,
                reporter: reporter,
                reporterGitHubUsername: reporterGitHubUsername
            )
            guard phase == .submitting else { return }
            canOffer = false
            mailDraft = outcome.mail
            phase = .succeeded(outcome.issue.htmlURL)
        } catch {
            guard phase == .submitting else { return }
            phase = .submitFailed(error.localizedDescription)
        }
    }
}
