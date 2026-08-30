import Darwin
import Foundation

/// Bild-Anhänge nur, wenn die Foundation-Models-Runtime den Initializer wirklich exportiert.
enum PasteImportImageAttachments {
    static var isSupported: Bool { cgImageInitializerAvailable || imageURLInitializerAvailable }

    static var cgImageInitializerAvailable: Bool {
        cgImageSymbols.contains(where: hasSymbol)
    }

    static var imageURLInitializerAvailable: Bool {
        imageURLSymbols.contains(where: hasSymbol)
    }

    /// `Attachment`-Initializer; aktuelle Runtime-Mangling zuerst.
    private static let cgImageSymbols = [
        "$s16FoundationModels10AttachmentVA2A05ImageC7ContentVRszlE_11orientationACyAEGSo10CGImageRefa_So0G19PropertyOrientationVSgtcfC",
        "$s16FoundationModels10AttachmentVA2A05ImageC7ContentVRszrlE_11orientationACyAEGSo10CGImageRefa_So26CGImagePropertyOrientationVSgtcfC",
        "$s16FoundationModels10AttachmentVA2A05ImageC7ContentVRszrlE_11orientationACyAEGSo10CGImageRefa_So0G19PropertyOrientationVSgtcfC",
    ]

    private static let imageURLSymbols = [
        "$s16FoundationModels10AttachmentVA2A05ImageC7ContentVRszlE8imageURL11orientationACyAEG0A00G0V_So26CGImagePropertyOrientationVSgtcfC",
        "$s16FoundationModels10AttachmentVA2A05ImageC7ContentVRszrlE8imageURL11orientationACyAEG0A00G0V_So26CGImagePropertyOrientationVSgtcfC",
    ]

    static func requireSupport(_ supported: Bool = isSupported) throws {
        guard supported else { throw PasteImportAdapterError.imageInputUnsupported }
    }

    private static func hasSymbol(_ name: String) -> Bool {
        let handle = UnsafeMutableRawPointer(bitPattern: -2)
        return dlsym(handle, name) != nil || dlsym(handle, "_" + name) != nil
    }
}
