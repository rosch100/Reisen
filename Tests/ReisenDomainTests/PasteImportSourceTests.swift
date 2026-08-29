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
