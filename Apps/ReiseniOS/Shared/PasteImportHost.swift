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
    let onSelectSavedBooking: (UUID) -> Void
    @ViewBuilder let content: Content

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var reviewPayload: PasteImportReviewPayload?
    @State private var reviewQueue = PasteImportReviewQueue()

    init(
        session: PasteImportSession,
        entry: @escaping () -> PasteImportEntry,
        onSelectSavedBooking: @escaping (UUID) -> Void = { _ in },
        @ViewBuilder content: () -> Content
    ) {
        self.session = session
        self.entry = entry
        self.onSelectSavedBooking = onSelectSavedBooking
        self.content = content()
    }

    var body: some View {
        content
            .pasteImportFlow(session: session, onReviewQueue: advanceQueue)
            .sheet(item: $reviewPayload, onDismiss: {
                // Swipe-Dismiss ruft onCancel nicht auf — Queue nur hier voranbringen.
                guard session.isReviewing else { return }
                advanceQueue()
            }) { payload in
                PasteImportReviewSheet(
                    payload: payload,
                    onCancel: {
                        reviewPayload = nil
                    },
                    onSaved: { bookingID in
                        onSelectSavedBooking(bookingID)
                        reviewPayload = nil
                    }
                )
                .id(payload.id)
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
            .onChange(of: session.isReviewing) { _, reviewing in
                guard !reviewing else { return }
                reviewPayload = nil
            }
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
        if !session.hasPendingCandidates {
            session.endReview()
        }
    }

    private func presentNextCandidate() {
        guard let candidate = session.nextCandidate() else {
            session.endReview()
            return
        }
        let total = session.hasPendingCandidates ? 2 : 1
        if let match = candidate.uniqueMatchedBooking {
            presentEnrich(candidate, match: match, index: 1, total: total)
        } else {
            presentNew(candidate, index: 1, total: total)
        }
    }

    private func presentEnrich(
        _ candidate: PasteImportCandidate,
        match: Booking,
        index: Int,
        total: Int
    ) {
        do {
            guard let booking = try booking(id: match.id) else {
                session.fail(L10n.string(.pasteImportErrorMatchMissing))
                return
            }
            session.beginReview()
            reviewPayload = .enriching(
                candidate: candidate,
                booking: booking,
                index: index,
                total: total
            )
        } catch {
            session.fail(L10n.string(.storeLoadFailed))
        }
    }

    private func presentNew(
        _ candidate: PasteImportCandidate,
        index: Int,
        total: Int
    ) {
        let entryTrip: SDTrip?
        do {
            entryTrip = try trip(id: session.tripID)
        } catch {
            session.fail(L10n.string(.storeLoadFailed))
            return
        }
        session.beginReview()
        reviewPayload = .creating(
            candidate: candidate,
            tripID: session.tripID,
            tripStart: entryTrip?.startDate,
            tripEnd: entryTrip?.endDate,
            index: index,
            total: total
        )
    }

    private func booking(id: UUID) throws -> SDBooking? {
        try modelContext.fetch(FetchDescriptor<SDBooking>(predicate: #Predicate { $0.id == id })).first
    }

    private func trip(id: UUID?) throws -> SDTrip? {
        guard let id else { return nil }
        return try modelContext.fetch(
            FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == id })
        ).first
    }
}
