import Foundation
import Testing
import ReisenDomain

@Test func pasteImportFilter_dropsExtractionWithoutTypeOrStart() {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let noType = PasteImportExtraction(startAt: start, title: "ICE")
    let noStart = PasteImportExtraction(bookingType: .train, title: "ICE")
    #expect(PasteImportFilter.apply([noType, noStart]).isEmpty)
}

@Test func pasteImportFilter_keepsTypeAndStart_placeholdersMissingEnd() {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let extraction = PasteImportExtraction(bookingType: .train, startAt: start, title: "ICE 123")
    let drafts = PasteImportFilter.apply([extraction])
    #expect(drafts.count == 1)
    #expect(drafts[0].bookingType == .train)
    #expect(drafts[0].startAt == start)
    #expect(drafts[0].endAt == start)
    #expect(drafts[0].endAtIsPlaceholder == true)
    #expect(drafts[0].title == "ICE 123")
}

@Test func pasteImportFilter_keepsExplicitEnd() {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let end = start.addingTimeInterval(7200)
    let extraction = PasteImportExtraction(bookingType: .flight, startAt: start, endAt: end)
    let drafts = PasteImportFilter.apply([extraction])
    #expect(drafts[0].endAt == end)
    #expect(drafts[0].endAtIsPlaceholder == false)
}

@Test func pasteImportFilter_defaultsMissingStatusToUnknown() {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let extraction = PasteImportExtraction(bookingType: .train, startAt: start)
    let drafts = PasteImportFilter.apply([extraction])
    #expect(drafts[0].status == .unknown)
}
