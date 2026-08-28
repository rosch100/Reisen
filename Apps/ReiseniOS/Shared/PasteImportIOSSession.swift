import Foundation
import SwiftData

import ReisenAppCore
import ReisenData
import ReisenDomain
import ReisenPasteImport

/// Modellstufe für Toolbar und Lauf — eine Auflösung, kein zweiter Pfad.
enum PasteImportModel {
    static func kind() -> PasteImportModelKind {
        PasteImportModelResolver.resolve(FoundationModelsPasteImportAvailability().availability())
    }
}

/// Die gewählte Datei liegt vor, ist aber nicht als Text, Bild oder PDF lesbar.
enum PasteImportIOSSourceError: Error, Equatable, Sendable {
    case unreadableFile
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
        case running
        case choosing([PasteImportCandidate])
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    /// Kandidaten, die der Nutzer noch im Editor prüft.
    private(set) var pending: [PasteImportCandidate] = []

    private var source: PasteImportSource?
    private var existing: [Booking] = []
    private var task: Task<Void, Never>?

    var isConfirmingPrivateCloudCompute: Bool { phase == .confirmingPrivateCloudCompute }
    var isRunning: Bool { phase == .running }

    var isChoosing: Bool {
        if case .choosing = phase { return true }
        return false
    }

    /// Fortschritt und Kandidatenliste teilen sich ein Sheet: SwiftUI zeigt pro View nur eines.
    var isPresentingSheet: Bool { isRunning || isChoosing }

    var candidates: [PasteImportCandidate] {
        if case .choosing(let candidates) = phase { return candidates }
        return []
    }

    var errorMessage: String? {
        if case .failed(let message) = phase { return message }
        return nil
    }

    var hasPendingCandidates: Bool { !pending.isEmpty }

    /// - Parameter source: `nil` heißt „keine verwertbare Quelle“ und endet als Fehler.
    func start(source: PasteImportSource?, in modelContext: ModelContext) {
        reset()
        guard let source else {
            phase = .failed(L10n.string(.pasteImportErrorSource))
            return
        }
        let kind = PasteImportModel.kind()
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
        guard case .choosing(let candidates) = phase else { return }
        phase = .idle
        pending = candidates
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

    func fail(_ message: String) {
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
        phase = .running
        task = Task { [weak self] in
            do {
                let candidates = try await PasteImportRun.run(
                    source: source,
                    kind: kind,
                    extractor: FoundationModelsPasteImportExtractor(kind: kind),
                    existing: existing
                )
                guard !Task.isCancelled else { return }
                self?.phase = .choosing(candidates)
            } catch {
                guard !Task.isCancelled else { return }
                self?.phase = .failed(Self.message(for: error))
            }
        }
    }

    private func reset() {
        task?.cancel()
        task = nil
        source = nil
        existing = []
        pending = []
        phase = .idle
    }

    private static func message(for error: Error) -> String {
        switch error {
        case PasteImportSourceError.empty,
            PasteImportIOSSourceError.unreadableFile,
            PasteImportAdapterError.unreadableSource,
            PasteImportAdapterError.imageConversionFailed:
            return L10n.string(.pasteImportErrorSource)
        case PasteImportRunError.modelUnavailable, PasteImportAdapterError.unavailable:
            return L10n.string(.pasteImportUnavailable)
        case PasteImportAdapterError.imageInputUnsupported:
            return L10n.string(.pasteImportErrorImageUnsupported)
        default:
            return L10n.string(.pasteImportErrorModel)
        }
    }
}
