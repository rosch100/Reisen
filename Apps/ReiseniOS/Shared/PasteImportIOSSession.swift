import Foundation
import SwiftData

import ReisenAppCore
import ReisenData
import ReisenDomain
import ReisenPasteImport

/// Die gewählte Datei liegt vor, ist aber nicht als Text, Bild oder PDF lesbar.
enum PasteImportIOSSourceError: Error, Equatable, Sendable {
    case unreadableFile
}

extension PasteImportIOSSourceError: PasteImportFailureClassifying {
    var pasteImportFailure: PasteImportFailure { .source }
}

/// Ein Paste-Import-Durchlauf auf iOS: Bestätigung, Lauf, Kandidatenliste, Editor-Warteschlange.
///
/// Der Lauf selbst liegt in `PasteImportRun`; diese Klasse hält nur den Zustand des Einstiegs.
/// Nach einem Fehler wird nicht mit einer anderen Modellstufe wiederholt.
@MainActor
@Observable
final class PasteImportIOSSession {
    enum Phase: Equatable {
        case idle
        case confirmingPrivateCloudCompute
        case running(PasteImportModelKind)
        case choosing(PasteImportRunResult)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    /// Kandidaten, die der Nutzer noch im Editor prüft.
    private(set) var pending: [PasteImportCandidate] = []
    /// Reise des laufenden Imports, aus dem Einstieg — nicht aus der Auswahl eines anderen Tabs.
    private(set) var tripID: UUID?

    private var source: PasteImportSource?
    private var existing: [Booking] = []
    private let runLifetime = PasteImportRunLifetime()
    let featureRequestFlow = PasteImportFailedFeatureRequestFlow()
    private var resumeAfterFeatureRequest: Phase?
    private var failedRecognitionReason: PasteImportFailedRecognitionReason?

    var isConfirmingPrivateCloudCompute: Bool { phase == .confirmingPrivateCloudCompute }

    /// Modellstufe des laufenden Imports; `nil`, solange kein Lauf offen ist.
    var runningKind: PasteImportModelKind? {
        if case .running(let kind) = phase { return kind }
        return nil
    }

    var isRunning: Bool { runningKind != nil }

    var isChoosing: Bool {
        if case .choosing = phase { return true }
        return false
    }

    /// Fortschritt und Kandidatenliste teilen sich ein Sheet: SwiftUI zeigt pro View nur eines.
    var isPresentingSheet: Bool { isRunning || isChoosing }

    var choosingResult: PasteImportRunResult? {
        if case .choosing(let result) = phase { return result }
        return nil
    }

    var errorMessage: String? {
        if case .failed(let message) = phase { return message }
        return nil
    }

    var isConfirmingFeatureRequest: Bool { featureRequestFlow.phase.showsConfirmAlert }

    var featureRequestSuccessURL: URL? {
        if case .succeeded(let url) = featureRequestFlow.phase { return url }
        return nil
    }

    var featureRequestSubmitError: String? {
        if case .submitFailed(let message) = featureRequestFlow.phase { return message }
        return nil
    }

    var canOfferFeatureRequest: Bool {
        source != nil && featureRequestFlow.canOffer
    }

    var hasPendingCandidates: Bool { !pending.isEmpty }

    /// Bestätigung, Lauf, Kandidatenliste, Meldung, Feature-Request oder Editor-Warteschlange ist offen.
    ///
    /// Ein zweiter Auslöser der Übergabe darf das nicht überschreiben.
    var isActive: Bool {
        phase != .idle || hasPendingCandidates || featureRequestFlow.phase != .idle
    }

    /// - Parameters:
    ///   - source: `nil` heißt „keine verwertbare Quelle“ und endet als Fehler.
    ///   - entry: bestimmt die Reise neuer Buchungen dieses Durchlaufs.
    func start(source: PasteImportSource?, entry: PasteImportEntry, in modelContext: ModelContext) {
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
        do {
            existing = try modelContext.fetch(FetchDescriptor<SDBooking>())
                .map(DomainMapper.booking(from:))
        } catch {
            phase = .failed(L10n.string(.storeLoadFailed))
            return
        }
        self.source = source
        if kind == .privateCloudCompute {
            phase = .confirmingPrivateCloudCompute
        } else {
            run(kind: kind)
        }
    }

    func confirmPrivateCloudCompute() {
        guard case .confirmingPrivateCloudCompute = phase else { return }
        run(kind: .privateCloudCompute)
    }

    func cancelConfirmation() {
        guard case .confirmingPrivateCloudCompute = phase else { return }
        reset()
    }

    func cancelRun() {
        guard case .running = phase else { return }
        reset()
    }

    /// Übernimmt die Kandidaten in die Editor-Warteschlange.
    func review() {
        guard case .choosing(let result) = phase else { return }
        phase = .idle
        pending = result.candidates
    }

    /// Schließt das Lauf-Sheet. Nach `review()` ist die Phase bereits gewechselt und nichts zu tun.
    func dismissSheet() {
        switch phase {
        case .running, .choosing:
            reset()
        case .idle, .confirmingPrivateCloudCompute, .failed:
            break
        }
    }

    /// Behält die Warteschlange: ein Fehler bei einem Kandidaten beendet nicht die übrigen.
    func dismissError() {
        guard case .failed = phase else { return }
        phase = .idle
    }

    func offerFailedFeatureRequest() {
        guard canOfferFeatureRequest else { return }
        resumeAfterFeatureRequest = phase
        featureRequestFlow.offer()
        phase = .idle
    }

    func cancelFailedFeatureRequest() {
        guard featureRequestFlow.cancelConfirmAlert() else { return }
        if let resume = resumeAfterFeatureRequest {
            phase = resume
            resumeAfterFeatureRequest = nil
        }
    }

    func confirmFailedFeatureRequest() {
        guard let document = source, let reason = failedRecognitionReason else { return }
        featureRequestFlow.startConfirm(
            source: document,
            reason: reason,
            reporter: GitHubIssueReporter.shared,
            reporterGitHubUsername: AppSettingsKeys.optionalFeedbackGitHubUsername()
        )
    }

    func dismissFeatureRequestSuccess() {
        reset()
    }

    func dismissFeatureRequestSubmitError() {
        featureRequestFlow.acknowledgeSubmitFailure()
        if let resume = resumeAfterFeatureRequest {
            phase = resume
        }
    }

    /// Beendet den laufenden Extract-Task, behält aber die Editor-Warteschlange.
    func fail(_ message: String) {
        runLifetime.invalidate()
        source = nil
        featureRequestFlow.reset()
        failedRecognitionReason = nil
        phase = .failed(message)
    }

    func nextCandidate() -> PasteImportCandidate? {
        guard !pending.isEmpty else { return nil }
        return pending.removeFirst()
    }

    private func run(kind: PasteImportModelKind) {
        guard let source else {
            phase = .failed(L10n.string(.pasteImportErrorSource))
            return
        }
        let existing = existing
        phase = .running(kind)
        runLifetime.begin { [weak self] id in
            guard let self else { return }
            do {
                let result = try await PasteImportRun.run(
                    source: source,
                    kind: kind,
                    extractor: FoundationModelsPasteImportExtractor(kind: kind),
                    existing: existing
                )
                self.runLifetime.complete(ifCurrent: id) {
                    self.failedRecognitionReason = self.featureRequestFlow.applyRunResult(result)
                    self.phase = .choosing(result)
                }
            } catch {
                self.runLifetime.complete(ifCurrent: id) {
                    self.failedRecognitionReason = self.featureRequestFlow.applyRunFailure(
                        PasteImportFailureMessage.failure(for: error)
                    )
                    self.phase = .failed(PasteImportFailureMessage.text(for: error))
                }
            }
        }
    }

    private func reset() {
        runLifetime.invalidate()
        source = nil
        existing = []
        pending = []
        tripID = nil
        resumeAfterFeatureRequest = nil
        failedRecognitionReason = nil
        featureRequestFlow.reset()
        phase = .idle
    }
}
