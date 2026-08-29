import Foundation
import Testing
import ReisenDomain

private let matchStart = Date(timeIntervalSince1970: 1_800_000_000)
private let matchEnd = matchStart.addingTimeInterval(86_400)
private let matchOtherStart = matchStart.addingTimeInterval(7 * 86_400)
private let matchOtherEnd = matchEnd.addingTimeInterval(7 * 86_400)
private let matchCalendar = Calendar(identifier: .gregorian)

private func matchHotel(
    id: UUID = UUID(),
    code: String? = nil,
    url: String? = nil,
    startAt: Date = matchStart,
    endAt: Date = matchEnd,
    provider: ProviderID = .check24
) -> Booking {
    Booking(
        id: id,
        provider: provider,
        bookingType: .hotel,
        confirmationCode: code,
        externalUrl: url,
        startAt: startAt,
        endAt: endAt
    )
}

private func matchDraft(_ extraction: PasteImportExtraction) throws -> PasteImportDraft {
    try #require(PasteImportFilter.apply([extraction]).first)
}

private func matchResult(_ draft: PasteImportDraft, _ existing: [Booking]) -> PasteImportMatch {
    PasteImportMatching.match(
        draft: draft,
        existing: existing,
        index: SyncBookingMatchIndex(existing: existing, calendar: matchCalendar),
        calendar: matchCalendar,
        normalizer: BookingTimeNormalizer()
    )
}

@Test func pasteImportMatching_uniqueConfirmationCode() throws {
    let existing = matchHotel(code: "ABC123", startAt: matchOtherStart, endAt: matchOtherEnd)
    let draft = try matchDraft(
        PasteImportExtraction(bookingType: .hotel, startAt: matchStart, endAt: matchEnd, confirmationCode: "ABC123")
    )
    #expect(matchResult(draft, [existing]) == .unique(existing))
}

@Test func pasteImportMatching_ambiguousConfirmationCode() throws {
    let a = matchHotel(code: "ABC123", startAt: matchStart, endAt: matchEnd)
    let b = matchHotel(code: "ABC123", startAt: matchOtherStart, endAt: matchOtherEnd)
    let draft = try matchDraft(
        PasteImportExtraction(bookingType: .hotel, startAt: matchStart, endAt: matchEnd, confirmationCode: "ABC123")
    )
    #expect(matchResult(draft, [a, b]) == .ambiguous)
}

@Test func pasteImportMatching_skipsFingerprintWhenEndPlaceholder() throws {
    let existing = matchHotel(startAt: matchStart, endAt: matchStart)
    let draft = try matchDraft(PasteImportExtraction(bookingType: .hotel, startAt: matchStart, title: "Hotel"))
    #expect(draft.endAtIsPlaceholder)
    #expect(matchResult(draft, [existing]) == .none)
}

@Test func pasteImportMatching_fingerprintWhenEndKnown() throws {
    let existing = matchHotel()
    let draft = try matchDraft(PasteImportExtraction(bookingType: .hotel, startAt: matchStart, endAt: matchEnd))
    #expect(matchResult(draft, [existing]) == .unique(existing))
}

@Test func pasteImportMatching_ambiguousFingerprint() throws {
    let a = matchHotel()
    let b = matchHotel()
    let draft = try matchDraft(PasteImportExtraction(bookingType: .hotel, startAt: matchStart, endAt: matchEnd))
    #expect(matchResult(draft, [a, b]) == .ambiguous)
}

@Test func pasteImportMatching_uniqueExternalUrl() throws {
    let existing = matchHotel(url: "https://example.com/booking/1", startAt: matchOtherStart, endAt: matchOtherEnd)
    let draft = try matchDraft(
        PasteImportExtraction(
            bookingType: .hotel,
            startAt: matchStart,
            endAt: matchEnd,
            externalUrl: "https://example.com/booking/1"
        )
    )
    #expect(matchResult(draft, [existing]) == .unique(existing))
}

@Test func pasteImportMatching_ambiguousExternalUrlCollision() throws {
    let a = matchHotel(url: "https://example.com/booking/1", startAt: matchStart, endAt: matchEnd)
    let b = matchHotel(url: "https://example.com/booking/1", startAt: matchOtherStart, endAt: matchOtherEnd)
    let draft = try matchDraft(
        PasteImportExtraction(
            bookingType: .hotel,
            startAt: matchStart,
            endAt: matchEnd,
            externalUrl: "https://example.com/booking/1"
        )
    )
    #expect(matchResult(draft, [a, b]) == .ambiguous)
}

@Test func pasteImportMatching_noneWithoutAnyCandidate() throws {
    let existing = matchHotel(code: "OTHER", startAt: matchOtherStart, endAt: matchOtherEnd)
    let draft = try matchDraft(
        PasteImportExtraction(bookingType: .hotel, startAt: matchStart, endAt: matchEnd, confirmationCode: "ABC123")
    )
    #expect(matchResult(draft, [existing]) == .none)
}
