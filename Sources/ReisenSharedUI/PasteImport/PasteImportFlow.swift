import SwiftUI
import ReisenAppCore
import ReisenDomain

public extension View {
    /// Bestätigung, Fortschritt, Kandidatenliste, Fehlermeldung und Feature-Request eines Paste-Import-Laufs.
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
                        canOfferFeatureRequest: session.canOfferFeatureRequest,
                        onCancel: { session.dismissSheet() },
                        onContinue: {
                            session.review()
                            onReviewQueue()
                        },
                        onRequestFeature: { session.offerFailedFeatureRequest() }
                    )
                    #if !os(macOS)
                    .reisenSheetDetents()
                    #endif
                }
            }
            .alert(
                L10n.string(.pasteImportErrorTitle),
                isPresented: Binding(
                    get: { session.errorMessage != nil },
                    set: { if !$0 { session.dismissError() } }
                )
            ) {
                if session.canOfferFeatureRequest {
                    Button(PasteImportFailedFeatureRequestPresentation().offerTitle) {
                        session.offerFailedFeatureRequest()
                    }
                }
                Button(L10n.string(.commonOk), role: .cancel) {
                    session.dismissError()
                    onReviewQueue()
                }
            } message: {
                if let errorMessage = session.errorMessage {
                    Text(errorMessage)
                }
            }
            .alert(
                PasteImportFailedFeatureRequestPresentation().title,
                isPresented: Binding(
                    get: { session.isConfirmingFeatureRequest },
                    set: { if !$0 { session.cancelFailedFeatureRequest() } }
                )
            ) {
                Button(PasteImportFailedFeatureRequestPresentation().sendTitle) {
                    session.confirmFailedFeatureRequest()
                }
                Button(PasteImportFailedFeatureRequestPresentation().cancelTitle, role: .cancel) {
                    session.cancelFailedFeatureRequest()
                }
                .keyboardShortcut(.defaultAction)
            } message: {
                Text(PasteImportFailedFeatureRequestPresentation().message)
            }
            .sheet(
                isPresented: Binding(
                    get: { session.featureRequestSuccessURL != nil },
                    set: { if !$0 { session.dismissFeatureRequestSuccess() } }
                )
            ) {
                let chrome = PasteImportFailedFeatureRequestPresentation()
                #if os(macOS)
                VStack(alignment: .leading, spacing: 12) {
                    Text(chrome.doneTitle)
                    PublicGitHubIssueLink(
                        url: session.featureRequestSuccessURL,
                        errorMessage: nil
                    )
                    Button(L10n.string(.commonOk)) {
                        session.dismissFeatureRequestSuccess()
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(24)
                .frame(minWidth: 280)
                #else
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(chrome.doneTitle)
                        PublicGitHubIssueLink(
                            url: session.featureRequestSuccessURL,
                            errorMessage: nil
                        )
                    }
                    .padding()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.string(.commonOk)) {
                                session.dismissFeatureRequestSuccess()
                            }
                        }
                    }
                }
                .reisenSheetDetents()
                #endif
            }
            .alert(
                L10n.string(.pasteImportErrorTitle),
                isPresented: Binding(
                    get: { session.featureRequestSubmitError != nil },
                    set: { if !$0 { session.dismissFeatureRequestSubmitError() } }
                )
            ) {
                Button(L10n.string(.commonOk), role: .cancel) {
                    session.dismissFeatureRequestSubmitError()
                }
            } message: {
                if let featureRequestSubmitError = session.featureRequestSubmitError {
                    Text(featureRequestSubmitError)
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
