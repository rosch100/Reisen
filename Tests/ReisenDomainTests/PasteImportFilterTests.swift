import Foundation
import Testing
import ReisenDomain

@Test func pasteImportFilter_dropsExtractionWithoutTypeOrStart() {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let noType = PasteImportExtraction(startAt: start, title: "ICE")
    let noStart = PasteImportExtraction(bookingType: .train, title: "ICE")
    #expect(PasteImportFilter.apply([noType, noStart]).isEmpty)
}

@Test func pasteImportFilter_keepsTypeAndStart_placeholdersMissingEnd() throws {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let extraction = PasteImportExtraction(bookingType: .train, startAt: start, title: "ICE 123")
    let drafts = PasteImportFilter.apply([extraction])
    #expect(drafts.count == 1)
    let draft = try #require(drafts.first)
    #expect(draft.bookingType == .train)
    #expect(draft.startAt == start)
    #expect(draft.endAt == start)
    #expect(draft.endAtIsPlaceholder == true)
    #expect(draft.title == "ICE 123")
}

@Test func pasteImportFilter_keepsExplicitEnd() throws {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let end = start.addingTimeInterval(7200)
    let extraction = PasteImportExtraction(bookingType: .flight, startAt: start, endAt: end)
    let drafts = PasteImportFilter.apply([extraction])
    let draft = try #require(drafts.first)
    #expect(draft.endAt == end)
    #expect(draft.endAtIsPlaceholder == false)
}

@Test func pasteImportFilter_defaultsMissingStatusToUnknown() throws {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let extraction = PasteImportExtraction(bookingType: .train, startAt: start)
    let drafts = PasteImportFilter.apply([extraction])
    let draft = try #require(drafts.first)
    #expect(draft.status == .unknown)
}

@Test func pasteImportFilter_trimsStringsAndDropsWhitespaceOnly() throws {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let blank = PasteImportExtraction(bookingType: .train, startAt: start, title: "   ")
    let padded = PasteImportExtraction(bookingType: .train, startAt: start, title: " ICE 123 ")
    let drafts = PasteImportFilter.apply([blank, padded])
    #expect(drafts.count == 2)
    #expect(try #require(drafts.first).title == nil)
    #expect(try #require(drafts.last).title == "ICE 123")
}
