import SwiftUI
import ReisenAppCore
import ReisenDomain

#if os(iOS)
import MessageUI
#elseif os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

enum PasteImportFailedMailComposeError: LocalizedError {
    case failed

    var errorDescription: String? {
        L10n.string(.pasteImportFeatureRequestMailFailed)
    }
}

@MainActor
public enum PasteImportFailedMailCompose {
    /// Erfolg-Sheet nur wenn Mail nicht eingerichtet ist — nach dem Composer kein GitHub-Link mehr.
    nonisolated public static func showsSuccessSheet(
        successURL: URL?,
        hasMailDraft: Bool,
        submitError: String?,
        mailCanSend: Bool
    ) -> Bool {
        successURL != nil && !hasMailDraft && submitError == nil && !mailCanSend
    }

    /// Nur `.completed`, solange der Draft noch da ist — sonst würde ein Composer-Fehler überschrieben.
    nonisolated public static func finishForDismissedMailSheet(
        hasDraft: Bool
    ) -> PasteImportFailedMailComposeFinish? {
        hasDraft ? .completed : nil
    }

    static func showsSuccessSheet<Session: PasteImportSessionControlling>(_ session: Session) -> Bool {
        showsSuccessSheet(
            successURL: session.featureRequestSuccessURL,
            hasMailDraft: session.featureRequestMailDraft != nil,
            submitError: session.featureRequestSubmitError,
            mailCanSend: canSend
        )
    }

    static func finishDismissedMailSheet<Session: PasteImportSessionControlling>(_ session: Session) {
        guard let finish = finishForDismissedMailSheet(
            hasDraft: session.featureRequestMailDraft != nil
        ) else { return }
        // Mail unavailable / Sheet-Dismiss ohne Composer: Issue-Link behalten.
        session.finishFeatureRequestMail(finish, closesSessionOnCompleted: false)
    }

    /// iOS: MessageUI. macOS: `mailto:` **und** Handler für `.eml` (nicht nur mailto).
    static var canSend: Bool {
        #if os(iOS)
        MFMailComposeViewController.canSendMail()
        #elseif os(macOS)
        hasMailtoHandler && hasEmlHandler
        #else
        false
        #endif
    }

    static func handleAppearingDraft<Session: PasteImportSessionControlling>(session: Session) {
        guard let draft = session.featureRequestMailDraft else { return }
        guard canSend else {
            finishDismissedMailSheet(session)
            return
        }
        #if os(macOS)
        do {
            try present(draft) { session.finishFeatureRequestMail($0, closesSessionOnCompleted: true) }
        } catch {
            session.finishFeatureRequestMail(
                PasteImportFailedMailComposeFinish.fromSharingFailure(error),
                closesSessionOnCompleted: true
            )
        }
        #endif
    }

    #if os(macOS)
    private static var hasMailtoHandler: Bool {
        guard let mailto = URL(string: "mailto:") else { return false }
        return NSWorkspace.shared.urlForApplication(toOpen: mailto) != nil
    }

    /// Launch-Services-Handler für RFC822/`.eml` — unabhängig von `mailto:`.
    private static var hasEmlHandler: Bool {
        guard let emlType = UTType(filenameExtension: "eml") else { return false }
        return NSWorkspace.shared.urlForApplication(toOpen: emlType) != nil
    }

    /// Completion-Callbacks pro `.eml`-URL — parallele `present`-Aufrufe überschreiben einander nicht.
    fileprivate static var openCallbacks: [URL: @MainActor (PasteImportFailedMailComposeFinish) -> Void] = [:]
    /// Hält die Datei, bis der Mailer sie gelesen hat (Cleanup verzögert).
    fileprivate static var pendingFileURLs: Set<URL> = []
    private static let mailerReadGraceNanoseconds: UInt64 = 60_000_000_000

    static func present(
        _ draft: PasteImportFailedMailDraft,
        onFinished: @escaping @MainActor (PasteImportFailedMailComposeFinish) -> Void
    ) throws {
        let fileURL = try PasteImportFailedMailAttachmentFile.writeUnique(
            data: draft.rfc822Data(),
            fileName: "reisen-paste-import.eml"
        )
        openCallbacks[fileURL] = onFinished
        pendingFileURLs.insert(fileURL)
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(fileURL, configuration: configuration) { app, error in
            Task { @MainActor in
                let finish = finishForOpenResult(app: app, error: error)
                completeOpen(fileURL: fileURL, finish: finish)
            }
        }
    }

    /// Nur `.completed`, wenn die öffnende App der `mailto:`-Default ist — sonst Fallback/Fehler.
    public static func finishForOpenResult(
        app: NSRunningApplication?,
        error: Error?
    ) -> PasteImportFailedMailComposeFinish {
        if let error {
            return PasteImportFailedMailComposeFinish.fromSharingFailure(error)
        }
        guard let app, isMailtoDefaultApplication(app) else {
            return .failed(L10n.string(.pasteImportFeatureRequestMailFailed))
        }
        return .completed
    }

    private static func isMailtoDefaultApplication(_ app: NSRunningApplication) -> Bool {
        guard let mailto = URL(string: "mailto:") else { return false }
        guard let mailAppURL = NSWorkspace.shared.urlForApplication(toOpen: mailto) else {
            return false
        }
        guard let opened = app.bundleURL else { return false }
        return opened.standardizedFileURL == mailAppURL.standardizedFileURL
    }

    fileprivate static func completeOpen(
        fileURL: URL,
        finish: PasteImportFailedMailComposeFinish
    ) {
        guard let onFinished = openCallbacks.removeValue(forKey: fileURL) else { return }
        onFinished(finish)
        // Mailer liest die Datei oft erst nach dem Open-Callback — Cleanup verzögern.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: mailerReadGraceNanoseconds)
            pendingFileURLs.remove(fileURL)
            PasteImportFailedMailAttachmentFile.removeContainerIfPresent(of: fileURL)
        }
    }
    #endif
}

#if os(iOS)
struct PasteImportFailedMailComposeView: UIViewControllerRepresentable {
    let draft: PasteImportFailedMailDraft
    let onFinished: @MainActor (PasteImportFailedMailComposeFinish) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([draft.to])
        controller.setSubject(draft.subject)
        controller.setMessageBody(draft.body, isHTML: false)
        controller.addAttachmentData(draft.data, mimeType: draft.mimeType, fileName: draft.fileName)
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinished: @MainActor (PasteImportFailedMailComposeFinish) -> Void

        init(onFinished: @escaping @MainActor (PasteImportFailedMailComposeFinish) -> Void) {
            self.onFinished = onFinished
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            let finish = PasteImportFailedMailComposeFinish.fromComposer(
                didFail: result == .failed,
                error: error
            )
            let callback = onFinished
            controller.dismiss(animated: true) {
                Task { @MainActor in
                    callback(finish)
                }
            }
        }
    }
}
#endif
