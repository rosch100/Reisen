import CoreGraphics
import Foundation
import PDFKit
import Testing
@testable import ReisenPasteImport

@Test func pasteImportPDFText_readsEmbeddedTextAndSkipsPageImages() throws {
    let content = try PasteImportPDFPreparation.prepare(try PDFTestData.helloFixture())
    #expect(try #require(content.text).contains("ICE 123"))
    #expect(content.pageImages.isEmpty)
}

@Test func pasteImportPDFText_pageWithoutTextBecomesPageImage() throws {
    let content = try PasteImportPDFPreparation.prepare(PDFTestData.blankPages(count: 2))
    #expect(content.text == nil)
    #expect(content.pageImages.count == 2)
    #expect(try #require(content.pageImages.first).count > 0)
}

@Test func pasteImportPDFText_hybridKeepsTextAndRendersTextlessPages() throws {
    let content = try PasteImportPDFPreparation.prepare(try PDFTestData.helloThenBlankPage())
    #expect(try #require(content.text).contains("ICE 123"))
    #expect(content.pageImages.count == 1)
}

@Test func pasteImportPDFText_capsRenderedTextlessPagesAtMax() throws {
    let count = PasteImportPDFPreparation.maxRenderedPages + 1
    let content = try PasteImportPDFPreparation.prepare(PDFTestData.blankPages(count: count))
    #expect(content.pageImages.count == PasteImportPDFPreparation.maxRenderedPages)
    #expect(content.sourceWasTruncated)
}

@Test func pasteImportPDFText_nonPDFBytesThrowUnreadableSource() {
    #expect(throws: PasteImportAdapterError.unreadableSource) {
        try PasteImportPDFPreparation.prepare(Data("ICE 123".utf8))
    }
}

@Test func pasteImportPDFText_emptyBytesThrowUnreadableSource() {
    #expect(throws: PasteImportAdapterError.unreadableSource) {
        try PasteImportPDFPreparation.prepare(Data())
    }
}

@Test func pasteImportPDFText_pageImagesArePNG() throws {
    let content = try PasteImportPDFPreparation.prepare(PDFTestData.blankPages(count: 1))
    let header = try #require(content.pageImages.first).prefix(8)
    #expect(Array(header) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
}

@Test func pasteImportPDFText_scannedPageImagesPassImageAttachmentGate() throws {
    let content = try PasteImportPDFPreparation.prepare(PDFTestData.blankPages(count: 1))
    #expect(content.pageImages.count == 1)
    PasteImportImageAttachmentGate.expectMatchesRuntime()
}

/// PDF-Bytes für die Tests: Fixture mit Text, generierte Seiten ohne Text.
private enum PDFTestData {
    enum Error: Swift.Error, CustomStringConvertible {
        case missingFixture(String)

        var description: String {
            switch self {
            case .missingFixture(let name):
                return "Test-Fixture fehlt im Resource-Bundle: \(name)"
            }
        }
    }

    static func helloFixture() throws -> Data {
        guard let url = Bundle.module.url(forResource: "hello", withExtension: "pdf", subdirectory: "Fixtures") else {
            throw Error.missingFixture("hello.pdf")
        }
        return try Data(contentsOf: url)
    }

    /// Text-Fixture plus eine textlose Folgeseite — Hybrid für Text und Scan im selben Prompt.
    static func helloThenBlankPage() throws -> Data {
        guard let document = PDFDocument(data: try helloFixture()) else {
            throw Error.missingFixture("hello.pdf")
        }
        guard let blank = PDFDocument(data: blankPages(count: 1))?.page(at: 0) else {
            preconditionFailure("Leere PDF-Seite nicht erzeugbar")
        }
        document.insert(blank, at: document.pageCount)
        guard let data = document.dataRepresentation() else {
            preconditionFailure("Hybrid-PDF nicht serialisierbar")
        }
        return data
    }

    /// Seiten mit gefüllter Fläche und ohne Textobjekte — das Gegenstück zum gescannten PDF.
    static func blankPages(count: Int) -> Data {
        var mediaBox = CGRect(x: 0, y: 0, width: 200, height: 100)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            preconditionFailure("CGPDFContext nicht erzeugbar")
        }
        for _ in 0..<count {
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
            context.fill(mediaBox)
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }
}
