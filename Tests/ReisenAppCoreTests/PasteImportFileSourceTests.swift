import Foundation
import Testing
import UniformTypeIdentifiers
import ReisenDomain

@Test func pasteImportFileSource_allowedTypesArePdfImageAndPlainText() {
    #expect(PasteImportFileSource.importedTypeIdentifiers == [
        UTType.pdf.identifier,
        UTType.image.identifier,
        UTType.plainText.identifier,
    ])
}

@Test func pasteImportFileSource_readsPdfPngAndUtf8Text() throws {
    let directory = try scratchDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let pdf = directory.appendingPathComponent("ticket.pdf")
    try Data("%PDF-1.1\n".utf8).write(to: pdf)
    #expect(try PasteImportFileSource.source(from: pdf) == .pdf(Data("%PDF-1.1\n".utf8)))

    let png = directory.appendingPathComponent("scan.png")
    try pngBytes.write(to: png)
    #expect(try PasteImportFileSource.source(from: png) == .image(pngBytes))

    let text = directory.appendingPathComponent("mail.txt")
    try Data("ICE 123 Berlin".utf8).write(to: text)
    #expect(try PasteImportFileSource.source(from: text) == .text("ICE 123 Berlin"))
}

@Test func pasteImportFileSource_rejectsUnsupportedAndDirectories() throws {
    let directory = try scratchDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let zip = directory.appendingPathComponent("archive.zip")
    try Data([0x50, 0x4B]).write(to: zip)
    #expect(throws: PasteImportFileSourceError.unsupportedType) {
        try PasteImportFileSource.source(from: zip)
    }

    let nested = directory.appendingPathComponent("folder", isDirectory: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

    let pdf = directory.appendingPathComponent("ok.pdf")
    try Data("%PDF-1.1\n".utf8).write(to: pdf)

    #expect(PasteImportFileSource.acceptedFiles(in: [zip, nested, pdf]) == [pdf])
}

@Test func pasteImportFileSource_unreadableUtf8PlainTextThrows() throws {
    let directory = try scratchDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let text = directory.appendingPathComponent("broken.txt")
    try Data([0xFF, 0xFE, 0x00]).write(to: text)
    #expect(throws: PasteImportFileSourceError.unreadable) {
        try PasteImportFileSource.source(from: text)
    }
}

@Test func pasteImportFileSource_shareIdentifiersAcceptFileURLAndContentTypes() {
    #expect(PasteImportFileSource.acceptsShareIdentifiers(["public.file-url"]))
    #expect(PasteImportFileSource.acceptsShareIdentifiers(["com.adobe.pdf"]))
    #expect(PasteImportFileSource.acceptsShareIdentifiers(["public.image"]))
    #expect(PasteImportFileSource.acceptsShareIdentifiers(["public.plain-text"]))
    #expect(!PasteImportFileSource.acceptsShareIdentifiers(["public.url"]))
    #expect(!PasteImportFileSource.acceptsShareIdentifiers(["public.html"]))
}

private func scratchDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("PasteImportFileSourceTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// 1×1 PNG, damit der Dateityp über die Endung `.png` erkannt wird.
private let pngBytes = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
