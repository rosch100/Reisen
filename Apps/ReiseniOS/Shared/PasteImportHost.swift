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
    @State private var reviewQueue = PasteImportReviewQueue()

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
            .pasteImportInboxAndDrop(
                isSessionActive: session.isActive,
                onDropped: startFromDroppedFiles,
                onExternal: consumeExternalFiles
            )
    }

    private func consumeExternalFiles() {
        beginPasteImportDrop(
            PasteImportDropStartResolver.consumeInbox(isSessionActive: session.isActive)
        )
    }

    private func startFromDroppedFiles(_ urls: [URL]) {
        beginPasteImportDrop(
            PasteImportDropStartResolver.resolve(
                urls: urls,
                isSessionActive: session.isActive
            )
        )
    }

    private func beginPasteImportDrop(_ start: PasteImportDropStart) {
        if case .ignore = start { return }
        let entry = entry()
        start.apply(
            onFail: session.fail,
            onSource: { source in
                session.start(
                    source: source,
                    entry: entry,
                    in: modelContext
                )
            }
        )
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
        reviewQueue.advance(ifPending: session.hasPendingCandidates) {
            presentNextCandidate()
        }
    }

    private func presentNextCandidate() {
        guard let candidate = session.nextCandidate() else { return }
        if let match = candidate.uniqueMatchedBooking {
            presentEnrich(candidate, match: match)
        } else {
            presentNew(candidate)
        }
    }

    private func presentEnrich(_ candidate: PasteImportCandidate, match: Booking) {
        do {
            guard let booking = try booking(id: match.id) else {
                // Ohne Bestandsbuchung nicht als „Neu“ weiterlaufen — das legte ein Duplikat an.
                session.fail(L10n.string(.pasteImportErrorMatchMissing))
                return
            }
            review = PasteImportReview.enriching(candidate: candidate, booking: booking)
        } catch {
            session.fail(L10n.string(.storeLoadFailed))
        }
    }

    private func presentNew(_ candidate: PasteImportCandidate) {
        do {
            review = PasteImportReview.creating(candidate: candidate, trip: try selectedTrip())
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
