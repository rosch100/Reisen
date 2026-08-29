import SwiftData
import SwiftUI

import ReisenAppCore
import ReisenPasteImport
import ReisenData
import ReisenDomain
import ReisenSharedUI

/// Rahmen des Paste-Imports auf iOS: gemeinsamer Flow, Editor und Share-Übergabe.
///
/// Der Lauf liegt in `PasteImportRun`, der Prefill in `PasteImportEditorPrefill`; hier stehen
/// Übergabe, Drop/„Öffnen mit“ und die Editor-Warteschlange. Die Share-Extension übergibt über
/// die Handoff-URL; beim Aktivieren wird nachgeholt, falls iOS die App nicht direkt geöffnet hat.
struct PasteImportHost<Content: View>: View {
    let session: PasteImportSession
    let entry: () -> PasteImportEntry
    @ViewBuilder let content: Content

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var review: PasteImportReview?

    init(
        session: PasteImportSession,
        entry: @escaping () -> PasteImportEntry,
        @ViewBuilder content: () -> Content
    ) {
        self.session = session
        self.entry = entry
        self.content = content()
    }

    var body: some View {
        content
            .pasteImportFlow(session: session, onReviewQueue: advanceQueue)
            .sheet(item: $review) { review in
                PasteImportReviewSheet(review: review) {
                    self.review = nil
                    advanceQueue()
                }
                .reisenSheetDetents()
            }
            .onOpenURL { url in
                if PasteImportHandoff.isHandoff(url) {
                    handleHandoff(trigger: .url)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                handleHandoff(trigger: .activation)
                consumeExternalFiles()
            }
            .onAppear {
                consumeExternalFiles()
            }
            .onReceive(NotificationCenter.default.publisher(for: .pasteImportExternalFilesOffered)) { _ in
                consumeExternalFiles()
            }
            .pasteImportDropTarget { urls in
                startFromDroppedFiles(urls)
            }
    }

    private func consumeExternalFiles() {
        startFromDroppedFiles(PasteImportExternalFileInbox.take())
    }

    private func startFromDroppedFiles(_ urls: [URL]) {
        let files = PasteImportFileSource.acceptedFiles(in: urls)
        switch PasteImportDropCoordinator.action(
            offeredURLCount: urls.count,
            acceptedFileCount: files.count,
            isSessionActive: session.isActive
        ) {
        case .ignore:
            return
        case .fail:
            session.fail(L10n.string(.pasteImportErrorSource))
        case .start:
            guard let url = files.first else {
                session.fail(L10n.string(.pasteImportErrorSource))
                return
            }
            do {
                session.start(
                    source: try PasteImportFileSource.source(from: url),
                    entry: entry(),
                    in: modelContext
                )
            } catch {
                session.fail(PasteImportFailureMessage.text(for: error))
            }
        }
    }

    /// Beide Auslöser der Übergabe über einen Konsum: `consumePending` ist idempotent, und die
    /// Entscheidung im `PasteImportHandoffCoordinator` verhindert, dass der zweite Auslöser den
    /// vom ersten gestarteten Lauf mit einem Fehler überschreibt.
    private func handleHandoff(trigger: PasteImportHandoffTrigger) {
        let action = PasteImportHandoffCoordinator.action(
            trigger: trigger,
            outcome: PasteImportHandoff.consumePending(),
            isSessionActive: session.isActive
        )
        switch action {
        case .start(let source):
            session.start(source: source, entry: .handoff, in: modelContext)
        case .ignore:
            break
        case .reportFailure:
            session.fail(L10n.string(.pasteImportErrorHandoff))
        }
    }

    /// Nächster Kandidat aus der Warteschlange in den Editor.
    ///
    /// Erst nach dem laufenden Update-Zyklus, sonst verschluckt ein noch schließendes Sheet
    /// (Kandidatenliste, Fehlerdialog) die neue Präsentation.
    private func advanceQueue() {
        guard session.hasPendingCandidates else { return }
        Task { @MainActor in
            await Task.yield()
            presentNextCandidate()
        }
    }

    private func presentNextCandidate() {
        guard let candidate = session.nextCandidate() else { return }
        if candidate.isErgaenzen {
            presentEnrich(candidate)
        } else {
            presentNew(candidate)
        }
    }

    private func presentEnrich(_ candidate: PasteImportCandidate) {
        guard case .unique(let match) = candidate.match else {
            // Ohne Bestandsbuchung nicht als „Neu“ weiterlaufen — das legte ein Duplikat an.
            session.fail(L10n.string(.pasteImportErrorMatchMissing))
            return
        }
        do {
            guard let booking = try booking(id: match.id) else {
                session.fail(L10n.string(.pasteImportErrorMatchMissing))
                return
            }
            review = PasteImportReview(
                draft: PasteImportEditorPrefill.draft(
                    for: candidate,
                    existing: booking
                ),
                booking: booking,
                trip: nil
            )
        } catch {
            session.fail(L10n.string(.storeLoadFailed))
        }
    }

    private func presentNew(_ candidate: PasteImportCandidate) {
        do {
            review = PasteImportReview(
                draft: PasteImportEditorPrefill.draft(
                    for: candidate,
                    existing: nil
                ),
                booking: nil,
                trip: try selectedTrip()
            )
        } catch {
            session.fail(L10n.string(.storeLoadFailed))
        }
    }

    private func booking(id: UUID) throws -> SDBooking? {
        try modelContext.fetch(FetchDescriptor<SDBooking>(predicate: #Predicate { $0.id == id })).first
    }

    /// Reise des laufenden Imports; sie kommt aus dem Einstieg, nicht aus einer fremden Tab-Auswahl.
    private func selectedTrip() throws -> SDTrip? {
        guard let tripID = session.tripID else { return nil }
        return try modelContext.fetch(
            FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == tripID })
        ).first
    }
}
