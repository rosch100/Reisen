import Foundation
import Testing
import ReisenDomain
import ReisenPasteImport

/// Live-Lauf gegen lokale Muster-Tickets. Nur mit `REISEN_LIVE_TICKET_DIR`, nie in CI.
@Test func liveExtractTicketsFromEnvDirectory() async throws {
    guard let dir = ProcessInfo.processInfo.environment["REISEN_LIVE_TICKET_DIR"], !dir.isEmpty else {
        return
    }
    let root = URL(fileURLWithPath: dir, isDirectory: true)
    let files = try FileManager.default.contentsOfDirectory(
        at: root,
        includingPropertiesForKeys: nil
    )
    .filter { ["pdf", "txt", "png", "jpg", "jpeg"].contains($0.pathExtension.lowercased()) }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
    #expect(!files.isEmpty)

    let kind = PasteImportModelResolver.resolve(
        FoundationModelsPasteImportAvailability().availability()
    )
    print("modelKind=\(kind)")
    guard kind != .unavailable else {
        Issue.record("Kein Foundation-Models-Modell verfügbar")
        return
    }
    let extractor = FoundationModelsPasteImportExtractor(kind: kind)

    var extractionFailures: [String] = []
    for file in files {
        print("\n==== \(file.lastPathComponent) ====")
        do {
            let source = try source(from: file)
            let prepared = try source.validated()
            if case .pdf(let data) = prepared {
                let content = try PasteImportPDFPreparation.prepare(data)
                print(
                    "prepare textChars=\(content.text?.count ?? 0) pageImages=\(content.pageImages.count)"
                )
            }
            let outcome = try await extractor.extract(from: prepared)
            let extractions = outcome.extractions
            let drafts = PasteImportFilter.apply(extractions)
            print(
                "extractions=\(extractions.count) kept=\(drafts.count) truncated=\(outcome.sourceWasTruncated)"
            )
            for (index, extraction) in extractions.enumerated() {
                print(
                    "  raw[\(index)] type=\(label(extraction.bookingType)) start=\(iso(extraction.startAt)) title=\(extraction.title ?? "-") code=\(extraction.confirmationCode ?? "-") from=\(extraction.locationFrom ?? "-") to=\(extraction.locationTo ?? "-")"
                )
            }
            for (index, draft) in drafts.enumerated() {
                print(
                    "  kept[\(index)] type=\(draft.bookingType.rawValue) start=\(iso(draft.startAt)) title=\(draft.title ?? "-") code=\(draft.confirmationCode ?? "-")"
                )
            }
        } catch {
            print("ERROR \(error)")
            extractionFailures.append("\(file.lastPathComponent): \(error)")
        }
    }
    if !extractionFailures.isEmpty {
        Issue.record(
            "Live-Extract fehlgeschlagen:\n\(extractionFailures.joined(separator: "\n"))"
        )
    }
}

private func source(from url: URL) throws -> PasteImportSource {
    switch url.pathExtension.lowercased() {
    case "pdf", "png", "jpg", "jpeg", "txt":
        return try PasteImportFileSource.source(from: url)
    default:
        throw PasteImportFileSourceError.unsupportedType
    }
}

private func label(_ type: BookingType?) -> String {
    type?.rawValue ?? "nil"
}

private func iso(_ date: Date?) -> String {
    guard let date else { return "nil" }
    return ISO8601DateFormatter().string(from: date)
}
