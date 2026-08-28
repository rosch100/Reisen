import SwiftData
import SwiftUI

import ReisenData
import ReisenDomain
import ReisenSharedUI

/// Editor für einen Kandidaten: Ergänzen einer Bestandsbuchung oder eine neue Buchung.
struct PasteImportReview: Identifiable {
    let id = UUID()
    let draft: BookingEditorDraft
    /// `nil` legt eine neue Buchung an.
    let booking: SDBooking?
    /// Reise der neuen Buchung; `nil` heißt „offene Buchung“.
    let trip: SDTrip?
}

/// Rahmen des Paste-Imports auf iOS: Bestätigung, Lauf, Kandidatenliste, Editor und Share-Übergabe.
///
/// Der Lauf liegt in `PasteImportRun`, der Prefill in `PasteImportEditorPrefill`; hier steht nur die
/// Präsentation. Die Übergabe der Share-Extension wird über `reisen://paste-import` konsumiert und
/// beim Aktivieren nachgeholt, falls iOS die App nicht direkt geöffnet hat.
struct PasteImportHost<Content: View>: View {
    let session: PasteImportIOSSession
    /// Reise, in der neue Buchungen landen; `nil` legt offene Buchungen an.
    let tripID: UUID?
    @ViewBuilder let content: Content

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var review: PasteImportReview?

    var body: some View {
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
                if session.isRunning {
                    PasteImportProgressSheet { session.cancelRun() }
                        .reisenSheetDetents()
                } else {
                    PasteImportCandidateSheet(
                        candidates: session.candidates,
                        onCancel: { session.dismissSheet() },
                        onContinue: {
                            session.review()
                            advanceQueue()
                        }
                    )
                    .reisenSheetDetents()
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
                    advanceQueue()
                }
            } message: {
                if let errorMessage = session.errorMessage {
                    Text(errorMessage)
                }
            }
            .sheet(item: $review) { review in
                PasteImportReviewSheet(review: review) {
                    self.review = nil
                    advanceQueue()
                }
                .reisenSheetDetents()
            }
            .onOpenURL { url in
                guard PasteImportHandoff.isHandoff(url) else { return }
                startSharedHandoff()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                startPendingHandoff()
            }
    }

    /// Die App wurde für die Übergabe geöffnet: eine fehlende Datei ist hier ein Fehler.
    private func startSharedHandoff() {
        do {
            session.start(source: try PasteImportHandoff.consume(), in: modelContext)
        } catch {
            session.fail(L10n.string(.pasteImportErrorHandoff))
        }
    }

    /// iOS startet die App nach dem Teilen nicht garantiert; ohne liegende Übergabe passiert nichts.
    private func startPendingHandoff() {
        do {
            guard let source = try PasteImportHandoff.consumePending() else { return }
            session.start(source: source, in: modelContext)
        } catch {
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
                    existing: booking,
                    tripStartDate: candidate.draft.startAt
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
                    existing: nil,
                    tripStartDate: candidate.draft.startAt
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

    private func selectedTrip() throws -> SDTrip? {
        guard let tripID else { return nil }
        return try modelContext.fetch(
            FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == tripID })
        ).first
    }
}

private struct PasteImportProgressSheet: View {
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(L10n.string(.pasteImportProgress))
            Button(L10n.string(.commonCancel), action: onCancel)
        }
        .padding(24)
    }
}

private struct PasteImportCandidateSheet: View {
    let candidates: [PasteImportCandidate]
    let onCancel: () -> Void
    let onContinue: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                PasteImportCandidateList(candidates: candidates)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string(.commonCancel), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string(.pasteImportContinue), action: onContinue)
                        .disabled(candidates.isEmpty)
                }
            }
        }
    }
}

private struct PasteImportReviewSheet: View {
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
    }
}
