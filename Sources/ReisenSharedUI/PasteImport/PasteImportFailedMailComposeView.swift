import SwiftUI
import ReisenAppCore
import ReisenDomain

#if os(iOS)
import MessageUI
#elseif os(macOS)
import AppKit
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
        session.finishFeatureRequestMail(finish)
    }

    static var canSend: Bool {
        #if os(iOS)
        MFMailComposeViewController.canSendMail()
        #elseif os(macOS)
        hasMailToHandler
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
            try present(draft) { session.finishFeatureRequestMail($0) }
        } catch {
            session.finishFeatureRequestMail(
                PasteImportFailedMailComposeFinish.fromSharingFailure(error)
            )
        }
        #endif
    }

    #if os(macOS)
    private static var hasMailToHandler: Bool {
        guard let mailto = URL(string: "mailto:") else { return false }
        return NSWorkspace.shared.urlForApplication(toOpen: mailto) != nil
    }

    /// Hält die `.eml`, bis der Default-Mailer sie geöffnet hat; Cleanup verzögert.
    fileprivate static var openLifetime: MailOpenLifetime?
    /// Verhindert Doppel-Completion; Datei bleibt während `pendingFileURLs` erhalten.
    fileprivate static var pendingFileURLs: Set<URL> = []

    static func present(
        _ draft: PasteImportFailedMailDraft,
        onFinished: @escaping @MainActor (PasteImportFailedMailComposeFinish) -> Void
    ) throws {
        let fileURL = try PasteImportFailedMailAttachmentFile.writeUnique(
            data: draft.rfc822Data(),
            fileName: "reisen-paste-import.eml"
        )
        let lifetime = MailOpenLifetime(fileURL: fileURL, onFinished: onFinished)
        openLifetime = lifetime
        pendingFileURLs.insert(fileURL)
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(fileURL, configuration: configuration) { _, error in
            Task { @MainActor in
                let finish: PasteImportFailedMailComposeFinish
                if let error {
                    finish = PasteImportFailedMailComposeFinish.fromSharingFailure(error)
                } else {
                    finish = .completed
                }
                completeOpen(fileURL: fileURL, finish: finish, onFinished: onFinished)
            }
        }
    }

    fileprivate static func completeOpen(
        fileURL: URL,
        finish: PasteImportFailedMailComposeFinish,
        onFinished: @MainActor @escaping (PasteImportFailedMailComposeFinish) -> Void
    ) {
        guard openLifetime != nil else { return }
        openLifetime = nil
        onFinished(finish)
        // Mailer liest die Datei oft erst nach dem Open-Callback — Cleanup verzögern.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            pendingFileURLs.remove(fileURL)
            PasteImportFailedMailAttachmentFile.removeContainerIfPresent(of: fileURL)
        }
    }
    #endif
}

#if os(macOS)
private final class MailOpenLifetime {
    let fileURL: URL
    let onFinished: @MainActor (PasteImportFailedMailComposeFinish) -> Void

    init(
        fileURL: URL,
        onFinished: @escaping @MainActor (PasteImportFailedMailComposeFinish) -> Void
    ) {
        self.fileURL = fileURL
        self.onFinished = onFinished
    }
}
#endif

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
