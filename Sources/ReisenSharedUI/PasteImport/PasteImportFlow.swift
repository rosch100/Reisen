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

    private var featureRequestChrome: PasteImportFailedFeatureRequestPresentation {
        PasteImportFailedFeatureRequestPresentation()
    }

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
                    Button(featureRequestChrome.offerTitle) {
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
                featureRequestChrome.title,
                isPresented: Binding(
                    get: { session.isConfirmingFeatureRequest },
                    set: { if !$0 { session.cancelFailedFeatureRequest() } }
                )
            ) {
                Button(featureRequestChrome.sendTitle) {
                    session.confirmFailedFeatureRequest()
                }
                Button(featureRequestChrome.cancelTitle, role: .cancel) {
                    session.cancelFailedFeatureRequest()
                }
                .keyboardShortcut(.defaultAction)
            } message: {
                Text(featureRequestChrome.message)
            }
            .sheet(
                isPresented: Binding(
                    get: { PasteImportFailedMailCompose.showsSuccessSheet(session) },
                    set: { if !$0 { session.dismissFeatureRequestSuccess() } }
                )
            ) {
                #if os(macOS)
                VStack(alignment: .leading, spacing: 12) {
                    PasteImportFailedFeatureRequestSuccessBody(
                        chrome: featureRequestChrome,
                        url: session.featureRequestSuccessURL
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
                    PasteImportFailedFeatureRequestSuccessBody(
                        chrome: featureRequestChrome,
                        url: session.featureRequestSuccessURL
                    )
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
            #if os(iOS)
            .sheet(item: Binding(
                get: {
                    PasteImportFailedMailCompose.canSend ? session.featureRequestMailDraft : nil
                },
                set: { newValue in
                    guard newValue == nil else { return }
                    PasteImportFailedMailCompose.finishDismissedMailSheet(session)
                }
            )) { draft in
                PasteImportFailedMailComposeView(draft: draft) { finish in
                    session.finishFeatureRequestMail(finish)
                }
            }
            #endif
            .onChange(of: session.featureRequestMailDraft?.id) { _, newID in
                guard newID != nil else { return }
                PasteImportFailedMailCompose.handleAppearingDraft(session: session)
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

private struct PasteImportFailedFeatureRequestSuccessBody: View {
    let chrome: PasteImportFailedFeatureRequestPresentation
    let url: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(chrome.doneTitle)
            if !PasteImportFailedMailCompose.canSend {
                Text(chrome.mailUnavailableMessage)
            }
            PublicGitHubIssueLink(url: url, errorMessage: nil)
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
