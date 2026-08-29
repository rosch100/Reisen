import Foundation
import Testing
import ReisenDomain

@Test func pasteImportFailedDocument_textUsesBodyNotBinary() {
    let doc = PasteImportFailedDocument.from(.text("Hallo"))
    #expect(doc.fileName == "paste.txt")
    #expect(doc.mimeType == "text/plain")
    #expect(doc.text == "Hallo")
    #expect(doc.binary == nil)
}

@Test func pasteImportFailedDocument_imageIsBinary() {
    let bytes = Data([0x89, 0x50, 0x4E, 0x47])
    let doc = PasteImportFailedDocument.from(.image(bytes))
    #expect(doc.fileName == "paste-image.bin")
    #expect(doc.mimeType == "application/octet-stream")
    #expect(doc.text == nil)
    #expect(doc.binary == bytes)
}

@Test func pasteImportFailedDocument_pdfIsBinary() {
    let bytes = Data([0x25, 0x50, 0x44, 0x46])
    let doc = PasteImportFailedDocument.from(.pdf(bytes))
    #expect(doc.fileName == "paste.pdf")
    #expect(doc.mimeType == "application/pdf")
    #expect(doc.text == nil)
    #expect(doc.binary == bytes)
}
