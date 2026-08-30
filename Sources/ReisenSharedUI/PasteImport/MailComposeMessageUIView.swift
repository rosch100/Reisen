#if os(iOS)
import SwiftUI
import MessageUI
import ReisenAppCore

struct PasteImportFailedMailComposeView: UIViewControllerRepresentable {
    let draft: PasteImportFailedMailDraft
    let onFinished: @MainActor (PasteImportFailedMailComposeFinish) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        let configuration = PasteImportFailedMailCompose.makeConfiguration(draft: draft)
        controller.setToRecipients(configuration.recipients)
        controller.setSubject(configuration.subject)
        controller.setMessageBody(configuration.body, isHTML: false)
        controller.addAttachmentData(
            configuration.attachmentData,
            mimeType: configuration.mimeType,
            fileName: configuration.fileName
        )
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
