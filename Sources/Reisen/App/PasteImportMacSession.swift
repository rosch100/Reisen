import AppKit
import Foundation
import SwiftData
import SwiftUI
import ReisenAppCore
import ReisenData
import ReisenDomain
import ReisenPasteImport
import ReisenSharedUI

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

extension View {
    /// Bestätigung, Fortschritt, Kandidatenliste und Fehlermeldung eines Paste-Import-Laufs.
    ///
    /// - Parameter onReviewQueue: läuft, sobald der nächste Kandidat in den Editor darf.
    func pasteImportFlow(
        session: PasteImportSession,
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
    let session: PasteImportSession
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
