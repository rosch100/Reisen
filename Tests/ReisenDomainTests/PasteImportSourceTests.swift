import Foundation
import Testing
import ReisenDomain

@Test func pasteImportSource_rejectsEmptyText() {
    #expect(throws: PasteImportSourceError.empty) {
        try PasteImportSource.text("  \n").validated()
    }
}

@Test func pasteImportSource_acceptsNonEmptyText() throws {
    let source = try PasteImportSource.text("ICE 123 Berlin").validated()
    #expect(source == .text("ICE 123 Berlin"))
}

@Test func pasteImportSource_rejectsEmptyData() {
    #expect(throws: PasteImportSourceError.empty) {
        try PasteImportSource.image(Data()).validated()
    }
    #expect(throws: PasteImportSourceError.empty) {
        try PasteImportSource.pdf(Data()).validated()
    }
}

@Test func pasteImportSource_payloadDataMatchesCaseBytes() {
    #expect(PasteImportSource.text("Hallo").payloadData == Data("Hallo".utf8))
    let bytes = Data([0x25, 0x50, 0x44, 0x46])
    #expect(PasteImportSource.pdf(bytes).payloadData == bytes)
    #expect(PasteImportSource.image(bytes).payloadData == bytes)
}

@Test func pasteImportSource_kindNameMatchesCase() {
    #expect(PasteImportSource.text("x").kindName == "text")
    #expect(PasteImportSource.image(Data([1])).kindName == "image")
    #expect(PasteImportSource.pdf(Data([1])).kindName == "pdf")
}

@Test func pasteImportSource_attachmentMetadataMatchesCase() {
    let text = PasteImportSource.text("x")
    #expect(text.attachmentFileName == "paste.txt")
    #expect(text.attachmentMimeType == "text/plain")
    let unknown = PasteImportSource.image(Data([1]))
    #expect(unknown.attachmentFileName == "paste-image.bin")
    #expect(unknown.attachmentMimeType == "application/octet-stream")
    let pdf = PasteImportSource.pdf(Data([1]))
    #expect(pdf.attachmentFileName == "paste.pdf")
    #expect(pdf.attachmentMimeType == "application/pdf")
}

@Test func pasteImportSource_imageAttachmentUsesMagicBytes() {
    let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00])
    let pngSource = PasteImportSource.image(png)
    #expect(pngSource.attachmentFileName == "paste-image.png")
    #expect(pngSource.attachmentMimeType == "image/png")

    let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00])
    let jpegSource = PasteImportSource.image(jpeg)
    #expect(jpegSource.attachmentFileName == "paste-image.jpg")
    #expect(jpegSource.attachmentMimeType == "image/jpeg")

    var heic = Data([0x00, 0x00, 0x00, 0x18])
    heic.append(contentsOf: "ftyp".utf8)
    heic.append(contentsOf: "heic".utf8)
    heic.append(Data(repeating: 0, count: 8))
    let heicSource = PasteImportSource.image(heic)
    #expect(heicSource.attachmentFileName == "paste-image.heic")
    #expect(heicSource.attachmentMimeType == "image/heic")
}

@Test func pasteImportSource_fromHandoffRoundTripsKinds() throws {
    let text = try PasteImportSource.fromHandoff(kind: .text, payload: Data("PNR".utf8))
    #expect(text == .text("PNR"))
    #expect(text.kind == .text)
    #expect(text.kind.rawValue == "text")
    #expect(text.fingerprintData == Data("PNR".utf8))

    let imagePayload = Data([0x01, 0x02])
    let image = try PasteImportSource.fromHandoff(kind: .image, payload: imagePayload)
    #expect(image == .image(imagePayload))

    let pdfPayload = Data([0x25, 0x50, 0x44, 0x46])
    let pdf = try PasteImportSource.fromHandoff(kind: .pdf, payload: pdfPayload)
    #expect(pdf == .pdf(pdfPayload))
}

@Test func pasteImportSource_fromHandoffRejectsBadTextAndUnknownKind() {
    #expect(throws: PasteImportSourceError.unreadableHandoff) {
        try PasteImportSource.fromHandoff(kind: .text, payload: Data([0xFF]))
    }
    #expect(PasteImportSource.Kind(rawValue: "video") == nil)
}
