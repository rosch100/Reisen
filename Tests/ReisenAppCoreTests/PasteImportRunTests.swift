import Foundation
import Testing
import ReisenAppCore
import ReisenDomain

private let runStart = Date(timeIntervalSince1970: 1_800_000_000)
private let runEnd = runStart.addingTimeInterval(86_400)
private let runCalendar = Calendar(identifier: .gregorian)

private enum FakeExtractError: Error, Equatable, Sendable {
    case modelFailed
}

/// Zählt die Aufrufe, damit ein zweiter Extract-Versuch auffällt.
private actor CountingExtractor: PasteImportExtracting {
    private(set) var extractCallCount = 0
    private let extractions: [PasteImportExtraction]
    private let failure: FakeExtractError?

    init(extractions: [PasteImportExtraction] = [], failure: FakeExtractError? = nil) {
        self.extractions = extractions
        self.failure = failure
    }

    func extract(from source: PasteImportSource) async throws -> [PasteImportExtraction] {
        extractCallCount += 1
        if let failure { throw failure }
        return extractions
    }
}

private func hotelExtraction(code: String?) -> PasteImportExtraction {
    PasteImportExtraction(
        bookingType: .hotel,
        startAt: runStart,
        endAt: runEnd,
        title: "Hotel Lissabon",
        confirmationCode: code
    )
}

private func hotelBooking(code: String) -> Booking {
    Booking(
        provider: .check24,
        bookingType: .hotel,
        confirmationCode: code,
        startAt: runStart,
        endAt: runEnd
    )
}

@Test func pasteImportRun_extractFailure_doesNotRunSecondExtract() async throws {
    let extractor = CountingExtractor(failure: .modelFailed)

    await #expect(throws: FakeExtractError.modelFailed) {
        try await PasteImportRun.run(
            source: .text("Hotel Lissabon"),
            kind: .privateCloudCompute,
            extractor: extractor,
            existing: [],
            calendar: runCalendar
        )
    }

    let extractCallCount = await extractor.extractCallCount
    #expect(extractCallCount == 1)
}

@Test func pasteImportRun_buildsCandidatesFromOneExtract() async throws {
    let extractor = CountingExtractor(extractions: [hotelExtraction(code: "X")])

    let candidates = try await PasteImportRun.run(
        source: .text("Hotel Lissabon"),
        kind: .onDevice,
        extractor: extractor,
        existing: [hotelBooking(code: "X")],
        calendar: runCalendar
    )

    let candidate = try #require(candidates.first)
    #expect(candidates.count == 1)
    #expect(candidate.isErgaenzen)
    let extractCallCount = await extractor.extractCallCount
    #expect(extractCallCount == 1)
}

@Test func pasteImportRun_unavailableModel_doesNotExtract() async throws {
    let extractor = CountingExtractor(extractions: [hotelExtraction(code: nil)])

    await #expect(throws: PasteImportRunError.modelUnavailable) {
        try await PasteImportRun.run(
            source: .text("Hotel Lissabon"),
            kind: .unavailable,
            extractor: extractor,
            existing: [],
            calendar: runCalendar
        )
    }

    let extractCallCount = await extractor.extractCallCount
    #expect(extractCallCount == 0)
}

@Test func pasteImportRun_emptySource_doesNotExtract() async throws {
    let extractor = CountingExtractor(extractions: [hotelExtraction(code: nil)])

    await #expect(throws: PasteImportSourceError.empty) {
        try await PasteImportRun.run(
            source: .text("   \n"),
            kind: .onDevice,
            extractor: extractor,
            existing: [],
            calendar: runCalendar
        )
    }

    let extractCallCount = await extractor.extractCallCount
    #expect(extractCallCount == 0)
}
