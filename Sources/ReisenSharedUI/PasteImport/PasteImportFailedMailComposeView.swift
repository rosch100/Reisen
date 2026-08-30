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

/// Draft für MessageUI (iOS) und `NSSharingService.composeEmail` (macOS).
/// Absichtlich ohne From — der Composer nimmt den Standard-Account.
struct PasteImportFailedMailComposeConfiguration: Equatable {
    let recipients: [String]
    let subject: String
    let body: String
    let attachmentData: Data
    let mimeType: String
    let fileName: String
}

#if os(macOS)
struct PasteImportFailedMailComposePrepared: Equatable {
    let configuration: PasteImportFailedMailComposeConfiguration
    let attachmentURL: URL
}
#endif

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

    /// iOS: MessageUI. macOS: der Composer des Standard-Mailclients.
    static var canSend: Bool {
        #if os(iOS)
        MFMailComposeViewController.canSendMail()
        #elseif os(macOS)
        guard let service = composeEmailService, hasMailtoHandler else { return false }
        return service.canPerform(withItems: mailAvailabilityItems)
        #else
        false
        #endif
    }

    static func makeConfiguration(
        draft: PasteImportFailedMailDraft
    ) -> PasteImportFailedMailComposeConfiguration {
        PasteImportFailedMailComposeConfiguration(
            recipients: [draft.to],
            subject: draft.subject,
            body: draft.body,
            attachmentData: draft.data,
            mimeType: draft.mimeType,
            fileName: draft.fileName
        )
    }

    static func handleAppearingDraft<Session: PasteImportSessionControlling>(
        session: Session,
        mailCanSend: Bool = canSend
    ) {
        handleAppearingDraft(
            draft: session.featureRequestMailDraft,
            mailCanSend: mailCanSend,
            finishUnavailable: { finishDismissedMailSheet(session) },
            presentDraft: { draft in
                #if os(macOS)
                try present(
                    draft,
                    using: composeEmailService,
                    perform: { $0.perform(withItems: $1) },
                    onFinished: { session.finishFeatureRequestMail($0, closesSessionOnCompleted: true) }
                )
                #endif
            },
            finishPresentFailure: { error in
                session.finishFeatureRequestMail(
                    PasteImportFailedMailComposeFinish.fromSharingFailure(error),
                    closesSessionOnCompleted: true
                )
            }
        )
    }

    static func handleAppearingDraft(
        draft: PasteImportFailedMailDraft?,
        mailCanSend: Bool,
        finishUnavailable: () -> Void,
        presentDraft: (PasteImportFailedMailDraft) throws -> Void,
        finishPresentFailure: (Error) -> Void
    ) {
        guard let draft else { return }
        guard mailCanSend else {
            finishUnavailable()
            return
        }
        #if os(macOS)
        do {
            try presentDraft(draft)
        } catch {
            finishPresentFailure(error)
        }
        #endif
    }

    #if os(macOS)
    private static let mailAvailabilityItems: [Any] = [""]

    private static var composeEmailService: NSSharingService? {
        NSSharingService(named: .composeEmail)
    }

    private static var hasMailtoHandler: Bool {
        guard let mailto = URL(string: "mailto:") else { return false }
        return NSWorkspace.shared.urlForApplication(toOpen: mailto) != nil
    }

    static var shareLifetime: MailShareLifetime?

    static func prepare(
        _ draft: PasteImportFailedMailDraft
    ) throws -> PasteImportFailedMailComposePrepared {
        let configuration = makeConfiguration(draft: draft)
        let attachmentURL = try PasteImportFailedMailAttachmentFile.writeUnique(
            data: configuration.attachmentData,
            fileName: configuration.fileName
        )
        return PasteImportFailedMailComposePrepared(
            configuration: configuration,
            attachmentURL: attachmentURL
        )
    }

    static func apply(
        _ prepared: PasteImportFailedMailComposePrepared,
        to service: NSSharingService
    ) -> [Any] {
        service.recipients = prepared.configuration.recipients
        service.subject = prepared.configuration.subject
        return [prepared.configuration.body, prepared.attachmentURL]
    }

    @discardableResult
    static func present(
        _ draft: PasteImportFailedMailDraft,
        using service: NSSharingService?,
        perform: (NSSharingService, [Any]) -> Void,
        onFinished: @escaping @MainActor (PasteImportFailedMailComposeFinish) -> Void
    ) throws -> URL {
        guard let service else {
            throw PasteImportFailedMailComposeError.failed
        }
        let prepared = try prepare(draft)
        let items = apply(prepared, to: service)
        guard service.canPerform(withItems: items) else {
            PasteImportFailedMailAttachmentFile.removeContainerIfPresent(of: prepared.attachmentURL)
            throw PasteImportFailedMailComposeError.failed
        }
        let lifetime = MailShareLifetime(fileURL: prepared.attachmentURL, onFinished: onFinished)
        shareLifetime = lifetime
        service.delegate = lifetime
        perform(service, items)
        return prepared.attachmentURL
    }

    static func completeShare(
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
