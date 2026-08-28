import Foundation
import Testing
import ReisenDomain

private let pipelineStart = Date(timeIntervalSince1970: 1_800_000_000)
private let pipelineEnd = pipelineStart.addingTimeInterval(86_400)
private let pipelineCalendar = Calendar(identifier: .gregorian)

private func pipelineHotel(code: String? = nil, provider: ProviderID = .check24) -> Booking {
    Booking(
        provider: provider,
        bookingType: .hotel,
        confirmationCode: code,
        startAt: pipelineStart,
        endAt: pipelineEnd
    )
}

private func pipelineExtraction(
    bookingType: BookingType? = .hotel,
    startAt: Date? = pipelineStart,
    code: String? = nil
) -> PasteImportExtraction {
    PasteImportExtraction(bookingType: bookingType, startAt: startAt, endAt: pipelineEnd, confirmationCode: code)
}

private func pipelineCandidates(
    _ extractions: [PasteImportExtraction],
    _ existing: [Booking]
) -> [PasteImportCandidate] {
    PasteImportPipeline.candidates(
        from: extractions,
        existing: existing,
        calendar: pipelineCalendar,
        normalizer: BookingTimeNormalizer()
    )
}

@Test func pasteImportPipeline_marksAmbiguousAsMatchCase() throws {
    let a = pipelineHotel(code: "X", provider: .check24)
    let b = pipelineHotel(code: "X", provider: .opodo)
    let candidates = pipelineCandidates([pipelineExtraction(code: "X")], [a, b])
    #expect(candidates.count == 1)
    let candidate = try #require(candidates.first)
    #expect(candidate.match == .ambiguous)
    #expect(candidate.showsAmbiguousHint)
    #expect(!candidate.isErgaenzen)
}

@Test func pasteImportPipeline_marksUniqueMatchAsErgaenzen() throws {
    let existing = pipelineHotel(code: "X")
    let candidates = pipelineCandidates([pipelineExtraction(code: "X")], [existing])
    let candidate = try #require(candidates.first)
    #expect(candidate.match == .unique(existing))
    #expect(candidate.isErgaenzen)
    #expect(!candidate.showsAmbiguousHint)
}

@Test func pasteImportPipeline_keepsUnmatchedDraftAsNewBooking() throws {
    let candidates = pipelineCandidates([pipelineExtraction(code: "X")], [])
    let candidate = try #require(candidates.first)
    #expect(candidate.match == .none)
    #expect(!candidate.isErgaenzen)
    #expect(!candidate.showsAmbiguousHint)
    #expect(candidate.draft.confirmationCode == "X")
}

@Test func pasteImportPipeline_dropsExtractionsWithoutTypeOrStart() {
    let candidates = pipelineCandidates(
        [
            pipelineExtraction(bookingType: nil),
            pipelineExtraction(startAt: nil),
            pipelineExtraction(code: "X")
        ],
        []
    )
    #expect(candidates.count == 1)
}
