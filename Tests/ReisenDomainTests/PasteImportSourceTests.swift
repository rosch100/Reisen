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
    let image = PasteImportSource.image(Data([1]))
    #expect(image.attachmentFileName == "paste-image.bin")
    #expect(image.attachmentMimeType == "application/octet-stream")
    let pdf = PasteImportSource.pdf(Data([1]))
    #expect(pdf.attachmentFileName == "paste.pdf")
    #expect(pdf.attachmentMimeType == "application/pdf")
}
