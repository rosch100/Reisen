import AppKit
import Foundation
import SwiftData
import SwiftUI
import ReisenAppCore
import ReisenData
import ReisenDomain
import ReisenPasteImport
import ReisenSharedUI

/// Modellstufe für Menü und Lauf — eine Auflösung, kein zweiter Pfad.
enum PasteImportModel {
    static func kind() -> PasteImportModelKind {
        PasteImportModelResolver.resolve(FoundationModelsPasteImportAvailability().availability())
    }
}

/// Quellen des macOS-Einstiegs: Zwischenablage und Dateiauswahl.
enum PasteImportMacSource {
    /// `nil`, wenn die Zwischenablage nichts Verwertbares enthält — kein Ersatzinhalt.
    static func fromPasteboard(_ pasteboard: NSPasteboard = .general) -> PasteImportSource? {
        if let pdf = pasteboard.data(forType: .pdf) { return .pdf(pdf) }
        if let png = pasteboard.data(forType: .png) { return .image(png) }
        if let tiff = pasteboard.data(forType: .tiff) { return .image(tiff) }
        if let text = pasteboard.string(forType: .string) { return .text(text) }
        return nil
    }

    /// `nil`, wenn der Nutzer die Auswahl abbricht.
    ///
    /// `begin()` statt `runModal()`: ein Menübefehl darf kein geschachteltes Modal starten,
    /// sonst erscheint der Dialog nicht.
    @MainActor
    static func fromOpenPanel() async throws -> PasteImportSource? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = PasteImportFileSource.allowedContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        let response = await panel.begin()
        guard response == .OK, let url = panel.url else { return nil }
        return try PasteImportFileSource.source(from: url)
    }
}

/// Ein Paste-Import-Durchlauf auf macOS: Bestätigung, Lauf, Kandidatenliste, Editor-Warteschlange.
///
/// Der Lauf selbst liegt in `PasteImportRun`; diese Klasse hält nur den Zustand des Einstiegs.
/// Nach einem Fehler wird nicht mit einer anderen Modellstufe wiederholt.
@MainActor
@Observable
final class PasteImportMacSession {
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
    /// Reise des laufenden Imports, aus dem Einstieg — nicht aus einer inzwischen anderen Auswahl.
    private(set) var tripID: UUID?

    private var source: PasteImportSource?
    private var existing: [Booking] = []
    private var task: Task<Void, Never>?
    /// Ungültig nach Cancel/`reset`/`fail` — verhindert späte Phase-Schreibvorgänge.
    private var runID = UUID()

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

    /// - Parameters:
    ///   - source: `nil` heißt „keine verwertbare Quelle“ und endet als Fehler.
    ///   - entry: bestimmt die Reise neuer Buchungen dieses Durchlaufs. Sie wird hier eingefroren,
    ///     damit ein Wechsel der Seitenleisten-Auswahl den offenen Editor nicht umleitet.
    func start(source: PasteImportSource?, entry: PasteImportEntry, existing: [Booking]) {
        reset()
        tripID = entry.tripID
        guard let source else {
            phase = .failed(L10n.string(.pasteImportErrorSource))
            return
        }
        let kind = PasteImportModel.kind()
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

    /// Beendet den laufenden Extract-Task, behält aber die Editor-Warteschlange.
    func fail(_ message: String) {
        invalidateRun()
        source = nil
        phase = .failed(message)
    }

    var hasPendingCandidates: Bool { !pending.isEmpty }

    /// Bestätigung, Lauf, Kandidatenliste, Meldung oder Editor-Warteschlange ist offen.
    var isActive: Bool { phase != .idle || hasPendingCandidates }

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
        let id = UUID()
        runID = id
        phase = .running(kind)
        task = Task { @MainActor [weak self] in
            do {
                let result = try await PasteImportRun.run(
                    source: source,
                    kind: kind,
                    extractor: FoundationModelsPasteImportExtractor(kind: kind),
                    existing: existing
                )
                self?.finishRun(id: id, outcome: .success(result))
            } catch {
                self?.finishRun(id: id, outcome: .failure(error))
            }
        }
    }

    private func finishRun(id: UUID, outcome: Result<PasteImportRunResult, Error>) {
        guard runID == id else { return }
        task = nil
        switch outcome {
        case .success(let result):
            phase = .choosing(result)
        case .failure(let error):
            phase = .failed(PasteImportFailureMessage.text(for: error))
        }
    }

    private func invalidateRun() {
        runID = UUID()
        task?.cancel()
        task = nil
    }

    private func reset() {
        invalidateRun()
        source = nil
        existing = []
        pending = []
        tripID = nil
        phase = .idle
    }
}

extension View {
    /// Bestätigung, Fortschritt, Kandidatenliste und Fehlermeldung eines Paste-Import-Laufs.
    ///
    /// - Parameter onReviewQueue: läuft, sobald der nächste Kandidat in den Editor darf.
    func pasteImportFlow(
        session: PasteImportMacSession,
        onReviewQueue: @escaping () -> Void
    ) -> some View {
        modifier(PasteImportFlowModifier(session: session, onReviewQueue: onReviewQueue))
    }

    /// Fenster-Drop und Inbox für Dock/„Öffnen mit“.
    func pasteImportMacDropAndOpen(
        onDropped: @escaping ([URL]) -> Void,
        onExternal: @escaping () -> Void
    ) -> some View {
        modifier(PasteImportMacDropAndOpenModifier(onDropped: onDropped, onExternal: onExternal))
    }
}

private struct PasteImportMacDropAndOpenModifier: ViewModifier {
    let onDropped: ([URL]) -> Void
    let onExternal: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .pasteImportExternalFilesOffered)) { _ in
                onExternal()
            }
            .onAppear(perform: onExternal)
            .pasteImportDropTarget(onURLs: onDropped)
    }
}

private struct PasteImportFlowModifier: ViewModifier {
    let session: PasteImportMacSession
    let onReviewQueue: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(
                L10n.string(.pasteImportPccConfirmTitle),
                isPresented: Binding(
                    get: { session.isConfirmingPrivateCloudCompute },
                    set: { if !$0 { session.cancelConfirmation() } }
                )
            ) {
                Button(L10n.string(.pasteImportPccConfirmOk)) {
                    session.confirmPrivateCloudCompute()
                }
                Button(L10n.string(.commonCancel), role: .cancel) {
                    session.cancelConfirmation()
                }
            } message: {
                Text(L10n.string(.pasteImportPccConfirmMessage))
            }
            .sheet(
                isPresented: Binding(
                    get: { session.isPresentingSheet },
                    set: { if !$0 { session.dismissSheet() } }
                )
            ) {
                if let kind = session.runningKind {
                    PasteImportProgressSheet(kind: kind) { session.cancelRun() }
                } else if let result = session.choosingResult {
                    PasteImportCandidateSheet(
                        result: result,
                        onCancel: { session.dismissSheet() },
                        onContinue: {
                            session.review()
                            onReviewQueue()
                        }
                    )
                }
            }
            .alert(
                L10n.string(.pasteImportErrorTitle),
                isPresented: Binding(
                    get: { session.errorMessage != nil },
                    set: { if !$0 { session.dismissError() } }
                )
            ) {
                Button(L10n.string(.commonOk), role: .cancel) {
                    session.dismissError()
                    onReviewQueue()
                }
            } message: {
                if let errorMessage = session.errorMessage {
                    Text(errorMessage)
                }
            }
    }
}

private struct PasteImportProgressSheet: View {
    let kind: PasteImportModelKind
    let onCancel: () -> Void

    var body: some View {
        let presentation = PasteImportProgressPresentation(kind: kind)

        VStack(spacing: 16) {
            ProgressView()
            Text(presentation.title)
            if let modelName = presentation.modelName {
                Text(modelName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button(L10n.string(.commonCancel), action: onCancel)
                .keyboardShortcut(.cancelAction)
        }
        .padding(24)
        .frame(minWidth: 280)
    }
}

private struct PasteImportCandidateSheet: View {
    let result: PasteImportRunResult
    let onCancel: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView {
                PasteImportCandidateList(result: result)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button(L10n.string(.commonCancel), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(L10n.string(.pasteImportContinue), action: onContinue)
                    .keyboardShortcut(.defaultAction)
                    .disabled(result.candidates.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 320)
    }
}

/// Editor für einen Kandidaten außerhalb des Reise-Inspectors (Offen oder Buchung ohne Reise-Kontext).
struct PasteImportReview: Identifiable {
    let id = UUID()
    let draft: BookingEditorDraft
    /// `nil` legt eine neue Buchung an.
    let booking: SDBooking?
    /// Reise der neuen Buchung aus dem Einstieg; `nil` heißt „offene Buchung“.
    let trip: SDTrip?
}

struct PasteImportReviewSheet: View {
    let review: PasteImportReview
    let onFinished: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var draft: BookingEditorDraft

    init(review: PasteImportReview, onFinished: @escaping () -> Void) {
        self.review = review
        self.onFinished = onFinished
        _draft = State(initialValue: review.draft)
    }

    private var showsSyncOverwriteHint: Bool {
        guard let booking = review.booking else { return false }
        return booking.provider != .manual
    }

    var body: some View {
        BookingEditorForm(
            title: review.booking == nil
                ? L10n.string(.editorCreateTitle)
                : L10n.string(.editorEditTitle),
            showsSyncOverwriteHint: showsSyncOverwriteHint,
            draft: $draft,
            providerReadOnly: review.booking != nil,
            onCancel: onFinished,
            onSave: {
                if let booking = review.booking {
                    try draft.apply(to: booking, in: modelContext)
                } else {
                    try BookingEditorDraft.createBooking(
                        from: draft,
                        trip: review.trip,
                        in: modelContext
                    )
                }
                onFinished()
            }
        )
        .frame(minWidth: 520, minHeight: 620)
    }
}
