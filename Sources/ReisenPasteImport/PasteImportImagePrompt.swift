import Foundation
import FoundationModels

/// Bildprompt. Runtime-SSOT: `PasteImportImageAttachments.requireSupport()`.
enum PasteImportImagePrompt {
    static func make(request: String, images: [Data]) throws -> (prompt: Prompt, temporaryImageURLs: [URL]) {
        try PasteImportImageAttachments.requireSupport()
        return try makeUsingSDK(request: request, images: images)
    }

    private static func makeUsingSDK(request: String, images: [Data]) throws -> (prompt: Prompt, temporaryImageURLs: [URL]) {
        let attachments: [Attachment<ImageAttachmentContent>]
        let temporaryImageURLs: [URL]
        if PasteImportImageAttachments.cgImageInitializerAvailable {
            attachments = try images.map { Attachment(try PasteImportImageData.image(from: $0)) }
            temporaryImageURLs = []
        } else {
            let urls = try PasteImportTemporaryPNGs.write(images)
            attachments = urls.map { Attachment(imageURL: $0) }
            temporaryImageURLs = urls
        }
        return (
            Prompt {
                request
                attachments
            },
            temporaryImageURLs
        )
    }
}
