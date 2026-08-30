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
    private let featureRequestChrome = PasteImportFailedFeatureRequestPresentation()

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let kind = session.runningKind {
                    PasteImportRunningStatusBar(kind: kind) {
                        session.cancelRun()
                    }
                }
            }
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
                if let result = session.choosingResult {
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
                    .presentationDetents([.large])
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
                .presentationDetents([.large])
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
            .onChange(of: session.isRunning) { wasRunning, isRunning in
                if isRunning {
                    #if os(iOS) || os(macOS)
                    AccessibilityNotification.Announcement(L10n.string(.pasteImportProgress)).post()
                    #endif
                    return
                }
                guard wasRunning else { return }
                let end = session.runEnd
                #if os(iOS) || os(macOS)
                AccessibilityNotification.Announcement(end.announcement).post()
                #endif
                if end.shouldAdvanceReviewQueue {
                    onReviewQueue()
                }
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
            Text(chrome.mailUnavailableMessage)
            PublicGitHubIssueLink(url: url, errorMessage: nil)
        }
    }
}

/// Nicht-modale Fortschrittsleiste während der Erkennung (HIG: kein Blocking-Sheet).
struct PasteImportRunningStatusBar: View {
    let kind: PasteImportModelKind
    let onCancel: () -> Void

    var body: some View {
        let presentation = PasteImportProgressPresentation(kind: kind)
        HStack(alignment: .center, spacing: 10) {
            ProgressView()
                .controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.title)
                    .font(.callout)
                if let modelName = presentation.modelName {
                    Text(modelName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Button(L10n.string(.commonCancel), action: onCancel)
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            [presentation.title, presentation.modelName]
                .compactMap { $0 }
                .joined(separator: ", ")
        )
    }
}
