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
