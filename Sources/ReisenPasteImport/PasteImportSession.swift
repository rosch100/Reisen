import Foundation
import Observation
import ReisenAppCore
import ReisenDomain

/// Ein Paste-Import-Durchlauf: Bestätigung, Lauf, Kandidatenliste, Editor-Warteschlange.
///
/// Der Lauf selbst liegt in `PasteImportRun`; diese Klasse hält nur den Zustand des Einstiegs.
/// Nach einem Fehler wird nicht mit einer anderen Modellstufe wiederholt.
///
/// macOS und iOS teilen diese Session; plattformspezifisch sind nur Quelle und UI.
@MainActor
@Observable
public final class PasteImportSession: PasteImportSessionControlling {
    public enum Phase: Equatable {
        case idle
        case confirmingPrivateCloudCompute
        case running(PasteImportModelKind)
        case choosing(PasteImportRunResult)
        case failed(String)
    }

    public private(set) var phase: Phase = .idle
    /// Kandidaten, die der Nutzer noch im Editor prüft.
    public private(set) var pending: [PasteImportCandidate] = []
    /// Reise des laufenden Imports, aus dem Einstieg — nicht aus einer inzwischen anderen Auswahl.
    public private(set) var tripID: UUID?

    private var source: PasteImportSource?
    private var existing: [Booking] = []
    private let runLifetime = PasteImportRunLifetime()
    private let featureRequestFlow = PasteImportFailedFeatureRequestFlow()
    private var resumeAfterFeatureRequest: Phase?
    private var failedRecognitionReason: PasteImportFailedRecognitionReason?

    public init() {}

    /// Stellt für die isolierte macOS-XCUI-Suite einen vollständigen Candidate bereit.
    /// Der produktive Extractor wird dabei nicht aufgerufen.
    public func injectTestingFixture(enabled: Bool = UITestingLaunch.shouldInjectPasteImportFixture) {
        guard enabled else { return }

        let startAt = Date(timeIntervalSince1970: 1_800_345_600)
        let draft = PasteImportDraft(
            bookingType: .hotel,
            startAt: startAt,
            endAt: startAt.addingTimeInterval(86_400),
            endAtIsPlaceholder: false,
            title: "UI Testing Imported Booking",
            status: .confirmed
        )
        reset()
        pending = [PasteImportCandidate(draft: draft, match: .none)]
    }

    public var isConfirmingPrivateCloudCompute: Bool { phase == .confirmingPrivateCloudCompute }

    /// Modellstufe des laufenden Imports; `nil`, solange kein Lauf offen ist.
    public var runningKind: PasteImportModelKind? {
        if case .running(let kind) = phase { return kind }
        return nil
    }

    public var isRunning: Bool { runningKind != nil }

    public var isChoosing: Bool {
        if case .choosing = phase { return true }
        return false
    }

    /// Kandidatenliste (0 Treffer / Feature-Request). Lauf-Progress ist nicht modal.
    public var isPresentingSheet: Bool {
        if case .choosing(let result) = phase {
            return result.candidates.isEmpty
        }
        return false
    }

    public var choosingResult: PasteImportRunResult? {
        if case .choosing(let result) = phase { return result }
        return nil
    }

    public var errorMessage: String? {
        if case .failed(let message) = phase { return message }
        return nil
    }

    public var isConfirmingFeatureRequest: Bool { featureRequestFlow.phase.showsConfirmAlert }

    public var featureRequestSuccessURL: URL? {
        if case .succeeded(let url) = featureRequestFlow.phase { return url }
        return nil
    }

    public var featureRequestSubmitError: String? {
        if case .submitFailed(let message) = featureRequestFlow.phase { return message }
        return featureRequestFlow.mailComposeError
    }

    public var featureRequestMailDraft: PasteImportFailedMailDraft? {
        featureRequestFlow.mailDraft
    }

    public var canOfferFeatureRequest: Bool {
        source != nil && featureRequestFlow.canOffer
    }

    public var hasPendingCandidates: Bool { !pending.isEmpty }

    /// Letzter Lauf wurde abgebrochen (für Accessibility-Ende-Ansage); `reset`/`start` löschen das.
    public private(set) var runWasCancelled = false

    /// Review-Fenster/Sheet ist offen (auch wenn `pending` schon geleert wurde).
    public private(set) var isReviewing = false

    /// Bestätigung, Lauf, Kandidatenliste, Meldung, Feature-Request, Review oder Warteschlange ist offen.
    public var isActive: Bool {
        phase != .idle
            || hasPendingCandidates
            || isReviewing
            || featureRequestFlow.phase != .idle
    }

    public func beginReview() {
        isReviewing = true
    }

    public func endReview() {
        isReviewing = false
    }

    /// - Parameters:
    ///   - source: `nil` heißt „keine verwertbare Quelle“ und endet als Fehler.
    ///   - entry: bestimmt die Reise neuer Buchungen dieses Durchlaufs.
    ///   - existing: vorhandene Buchungen für Matching/Merge.
    public func start(source: PasteImportSource?, entry: PasteImportEntry, existing: [Booking]) {
        reset()
        tripID = entry.tripID
        guard let source else {
            phase = .failed(L10n.string(.pasteImportErrorSource))
            return
        }
        let kind = PasteImportResolvedModel.kind()
        guard kind != .unavailable else {
            phase = .failed(L10n.string(.pasteImportUnavailable))
            return
        }
        self.source = source
        self.existing = existing
        if kind == .privateCloudCompute {
            phase = .confirmingPrivateCloudCompute
        } else {
            run(kind: kind)
        }
    }

    public func confirmPrivateCloudCompute() {
        guard case .confirmingPrivateCloudCompute = phase else { return }
        run(kind: .privateCloudCompute)
    }

    public func cancelConfirmation() {
        guard case .confirmingPrivateCloudCompute = phase else { return }
        reset()
    }

    public func cancelRun() {
        guard case .running = phase else { return }
        reset()
        runWasCancelled = true
    }

    /// Übernimmt die Kandidaten in die Editor-Warteschlange.
    public func review() {
        guard case .choosing(let result) = phase else { return }
        phase = .idle
        pending = result.candidates
    }

    /// Schließt das Lauf-Sheet. Nach `review()` ist die Phase bereits gewechselt und nichts zu tun.
    public func dismissSheet() {
        switch phase {
        case .running, .choosing:
            reset()
        case .idle, .confirmingPrivateCloudCompute, .failed:
            break
        }
    }

    /// Behält die Warteschlange: ein Fehler bei einem Kandidaten beendet nicht die übrigen.
    public func dismissError() {
        guard case .failed = phase else { return }
        phase = .idle
    }

    public func offerFailedFeatureRequest() {
        guard canOfferFeatureRequest else { return }
        resumeAfterFeatureRequest = phase
        featureRequestFlow.offer()
        phase = .idle
    }

    public func cancelFailedFeatureRequest() {
        guard featureRequestFlow.cancelConfirmAlert() else { return }
        if let resume = resumeAfterFeatureRequest {
            phase = resume
            resumeAfterFeatureRequest = nil
        }
    }

    public func confirmFailedFeatureRequest() {
        guard let document = source, let reason = failedRecognitionReason else { return }
        featureRequestFlow.startConfirm(
            source: document,
            reason: reason,
            reporter: GitHubIssueReporter.shared,
            reporterGitHubUsername: AppSettingsKeys.optionalFeedbackGitHubUsername()
        )
    }

    public func dismissFeatureRequestSuccess() {
        reset()
    }

    public func dismissFeatureRequestSubmitError() {
        if featureRequestFlow.mailComposeError != nil {
            featureRequestFlow.finishMailCompose(.completed)
            return
        }
        featureRequestFlow.acknowledgeSubmitFailure()
        if let resume = resumeAfterFeatureRequest {
            phase = resume
        }
    }

    public func finishFeatureRequestMail(
        _ finish: PasteImportFailedMailComposeFinish,
        closesSessionOnCompleted: Bool = true
    ) {
        featureRequestFlow.finishMailCompose(finish)
        // Nach Mailer-Handoff: kein GitHub-Link-Sheet — Session schließen.
        // Bei Mail unavailable Draft verwerfen, Issue-Link behalten.
        if case .completed = finish, closesSessionOnCompleted {
            reset()
        }
    }

    /// Beendet den laufenden Extract-Task, behält aber die Editor-Warteschlange.
    public func fail(_ message: String) {
        clearSourceAndFeatureRequest()
        phase = .failed(message)
    }

    /// Setzt den Durchlauf zurück und meldet einen Fehler (z. B. SwiftData-Laden vor dem Lauf).
    public func fail(entry: PasteImportEntry, message: String) {
        reset()
        tripID = entry.tripID
        phase = .failed(message)
    }

    public func nextCandidate() -> PasteImportCandidate? {
        guard !pending.isEmpty else { return nil }
        return pending.removeFirst()
    }

    private func run(kind: PasteImportModelKind) {
        guard let source else {
            phase = .failed(L10n.string(.pasteImportErrorSource))
            return
        }
        let existing = existing
        let extractor = FoundationModelsPasteImportExtractor(kind: kind)
        phase = .running(kind)
        runLifetime.begin(
            work: {
                try await PasteImportRun.run(
                    source: source,
                    kind: kind,
                    extractor: extractor,
                    existing: existing
                )
            },
            onSuccess: { [weak self] result in
                guard let self else { return }
                self.failedRecognitionReason = self.featureRequestFlow.applyRunResult(result)
                if result.candidates.isEmpty {
                    self.phase = .choosing(result)
                } else {
                    self.pending = result.candidates
                    self.phase = .idle
                }
            },
            onFailure: { [weak self] error in
                guard let self else { return }
                self.failedRecognitionReason = self.featureRequestFlow.applyRunFailure(
                    PasteImportFailureMessage.failure(for: error)
                )
                self.phase = .failed(PasteImportFailureMessage.text(for: error))
            }
        )
    }

    private func clearSourceAndFeatureRequest() {
        runLifetime.invalidate()
        source = nil
        featureRequestFlow.reset()
        failedRecognitionReason = nil
        resumeAfterFeatureRequest = nil
    }

    private func reset() {
        clearSourceAndFeatureRequest()
        existing = []
        pending = []
        tripID = nil
        isReviewing = false
        runWasCancelled = false
        phase = .idle
    }
}
