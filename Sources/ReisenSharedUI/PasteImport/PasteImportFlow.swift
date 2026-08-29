import SwiftData
import SwiftUI
import ReisenAppCore
import ReisenData
import ReisenDomain

public extension View {
    /// Bestätigung, Fortschritt, Kandidatenliste und Fehlermeldung eines Paste-Import-Laufs.
    ///
    /// - Parameter onReviewQueue: läuft, sobald der nächste Kandidat in den Editor darf.
    func pasteImportFlow<Session: PasteImportSessionControlling & Observable>(
        session: Session,
        onReviewQueue: @escaping () -> Void
    ) -> some View {
        modifier(PasteImportFlowModifier(session: session, onReviewQueue: onReviewQueue))
    }
}

private struct PasteImportFlowModifier<Session: PasteImportSessionControlling & Observable>: ViewModifier {
    @Bindable var session: Session
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

struct PasteImportProgressSheet: View {
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
            #if os(macOS)
                .keyboardShortcut(.cancelAction)
            #endif
        }
        .padding(24)
        #if os(macOS)
        .frame(minWidth: 280)
        #else
        .reisenSheetDetents()
        #endif
    }
}

struct PasteImportCandidateSheet: View {
    let result: PasteImportRunResult
    let onCancel: () -> Void
    let onContinue: () -> Void

    var body: some View {
        #if os(macOS)
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
        #else
        NavigationStack {
            ScrollView {
                PasteImportCandidateList(result: result)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string(.commonCancel), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string(.pasteImportContinue), action: onContinue)
                        .disabled(result.candidates.isEmpty)
                }
            }
        }
        .reisenSheetDetents()
        #endif
    }
}
