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
    nonisolated public static func showsSuccessSheet(
        successURL: URL?,
        hasMailDraft: Bool,
        submitError: String?
    ) -> Bool {
        successURL != nil && !hasMailDraft && submitError == nil
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
            submitError: session.featureRequestSubmitError
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
        guard let service = composeEmailService, hasMailToHandler else { return false }
        return service.canPerform(withItems: mailAvailabilityItems)
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
    private static let mailAvailabilityItems: [Any] = [""]

    private static var composeEmailService: NSSharingService? {
        NSSharingService(named: .composeEmail)
    }

    private static var hasMailToHandler: Bool {
        guard let mailto = URL(string: "mailto:") else { return false }
        return NSWorkspace.shared.urlForApplication(toOpen: mailto) != nil
    }

    fileprivate static var shareLifetime: MailShareLifetime?

    static func present(
        _ draft: PasteImportFailedMailDraft,
        onFinished: @escaping @MainActor (PasteImportFailedMailComposeFinish) -> Void
    ) throws {
        guard let service = composeEmailService else {
            throw PasteImportFailedMailComposeError.failed
        }
        let fileURL = try PasteImportFailedMailAttachmentFile.writeUnique(
            data: draft.data,
            fileName: draft.fileName
        )
        let items: [Any] = [draft.body, fileURL]
        guard service.canPerform(withItems: items) else {
            PasteImportFailedMailAttachmentFile.removeContainerIfPresent(of: fileURL)
            throw PasteImportFailedMailComposeError.failed
        }
        let lifetime = MailShareLifetime(fileURL: fileURL, onFinished: onFinished)
        shareLifetime = lifetime
        service.delegate = lifetime
        service.recipients = [draft.to]
        service.subject = draft.subject
        service.perform(withItems: items)
    }

    fileprivate static func completeShare(
        fileURL: URL,
        finish: PasteImportFailedMailComposeFinish,
        onFinished: @MainActor @escaping (PasteImportFailedMailComposeFinish) -> Void
    ) {
        guard shareLifetime != nil else { return }
        shareLifetime = nil
        PasteImportFailedMailAttachmentFile.removeContainerIfPresent(of: fileURL)
        onFinished(finish)
    }
    #endif
}

#if os(macOS)
private final class MailShareLifetime: NSObject, NSSharingServiceDelegate {
    private let fileURL: URL
    private let onFinished: @MainActor (PasteImportFailedMailComposeFinish) -> Void

    init(
        fileURL: URL,
        onFinished: @escaping @MainActor (PasteImportFailedMailComposeFinish) -> Void
    ) {
        self.fileURL = fileURL
        self.onFinished = onFinished
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        complete(.completed)
    }

    func sharingService(
        _ sharingService: NSSharingService,
        didFailToShareItems items: [Any],
        error: Error
    ) {
        complete(PasteImportFailedMailComposeFinish.fromSharingFailure(error))
    }

    private func complete(_ finish: PasteImportFailedMailComposeFinish) {
        let fileURL = self.fileURL
        let onFinished = self.onFinished
        Task { @MainActor in
            PasteImportFailedMailCompose.completeShare(
                fileURL: fileURL,
                finish: finish,
                onFinished: onFinished
            )
        }
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
