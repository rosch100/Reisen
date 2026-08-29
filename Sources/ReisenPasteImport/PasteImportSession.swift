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
public final class PasteImportSession {
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

    public init() {}

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

    /// Fortschritt und Kandidatenliste teilen sich ein Sheet: SwiftUI zeigt pro View nur eines.
    public var isPresentingSheet: Bool { isRunning || isChoosing }

    public var choosingResult: PasteImportRunResult? {
        if case .choosing(let result) = phase { return result }
        return nil
    }

    public var errorMessage: String? {
        if case .failed(let message) = phase { return message }
        return nil
    }

    public var hasPendingCandidates: Bool { !pending.isEmpty }

    /// Bestätigung, Lauf, Kandidatenliste, Meldung oder Editor-Warteschlange ist offen.
    public var isActive: Bool { phase != .idle || hasPendingCandidates }

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

    /// Beendet den laufenden Extract-Task, behält aber die Editor-Warteschlange.
    public func fail(_ message: String) {
        runLifetime.invalidate()
        source = nil
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
                    self.phase = .choosing(result)
                }
            } catch {
                self.runLifetime.complete(ifCurrent: id) {
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
        phase = .idle
    }
}
