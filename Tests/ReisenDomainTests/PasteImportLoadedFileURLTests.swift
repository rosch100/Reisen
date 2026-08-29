import Foundation
import Testing
import ReisenDomain

@Test func pasteImportLoadedFileURL_acceptsURLObject() {
    let url = URL(fileURLWithPath: "/tmp/ticket.pdf")
    #expect(PasteImportLoadedFileURL.url(fromLoadedItem: url) == url)
}

@Test func pasteImportLoadedFileURL_acceptsBookmarkData() throws {
    let url = URL(fileURLWithPath: "/tmp/paste-import-bookmark-\(UUID().uuidString).pdf")
    try Data("%PDF-1.1\n".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    let data = try url.bookmarkData(
        options: [.suitableForBookmarkFile],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
    )
    let resolved = try #require(PasteImportLoadedFileURL.url(fromLoadedItem: data))
    #expect(resolved.standardizedFileURL.path == url.standardizedFileURL.path)
}

@Test func pasteImportLoadedFileURL_rejectsGarbage() {
    #expect(PasteImportLoadedFileURL.url(fromLoadedItem: nil) == nil)
    #expect(PasteImportLoadedFileURL.url(fromLoadedItem: "not-a-url") == nil)
    #expect(PasteImportLoadedFileURL.url(fromLoadedItem: Data([0x00, 0x01])) == nil)
}
