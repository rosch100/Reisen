#if os(macOS)
import AppKit
import ReisenAppCore

final class MailShareLifetime: NSObject, NSSharingServiceDelegate {
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
