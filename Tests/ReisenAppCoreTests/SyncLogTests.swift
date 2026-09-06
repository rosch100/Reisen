import Testing
import Foundation
import ReisenDiagnostics
@testable import ReisenAppCore

@Test func syncLog_appendWritesTimestampedLine() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-sync-log-\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: url) }
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    SyncLog.append("result=failure provider=opodo", to: url, now: now)
    let text = try String(contentsOf: url, encoding: .utf8)
    #expect(text.contains("result=failure provider=opodo"))
    #expect(text.contains("2023-11-14"))
}

@Test func syncLog_appendRedactsSecretsAtWriteTime() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-sync-log-redact-\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: url) }
    SyncLog.append("Bearer eyJhbGciOiJIUzI1NiJ9.payload.sig leak@example.com", to: url, now: Date())
    let text = try String(contentsOf: url, encoding: .utf8)
    #expect(!text.contains("eyJhbGciOiJIUzI1NiJ9.payload.sig"))
    #expect(!text.contains("leak@example.com"))
    #expect(text.contains("[redacted]"))
}

@Test func syncLog_recentTailMissingWhenFileAbsent() {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-sync-log-missing-\(UUID().uuidString).txt")
    let attachment = SyncLog.recentTail(fileURL: url)
    #expect(attachment == .missing)
}

@Test func syncLog_recentTailRedactsAndTruncates() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-sync-log-tail-\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: url) }
    let prefix = String(repeating: "x", count: 200)
    try Data("\(prefix)\ngast@domain.de\n".utf8).write(to: url)
    let attachment = SyncLog.recentTail(maxBytes: 40, fileURL: url)
    guard case .attached(let preview, _, _, _, let fileByteCount, let truncated) = attachment else {
        Issue.record("expected attached log")
        return
    }
    #expect(truncated)
    #expect(fileByteCount > 40)
    #expect(!preview.contains("gast@domain.de"))
    #expect(preview.contains("[redacted]") || preview.contains("x"))
}

@Test func syncLog_rotatesWhenOverMaxFileBytes() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-sync-log-rotate-\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: url) }
    let oversized = Data(repeating: UInt8(ascii: "a"), count: SyncLog.maxFileBytes + 10)
    try oversized.write(to: url)
    SyncLog.rotateIfNeeded(at: url)
    let sizeNumber = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber
    guard let sizeNumber else {
        Issue.record("expected file size after rotation")
        return
    }
    #expect(sizeNumber.intValue <= SyncLog.keepBytes)
}

@Test func syncLog_lineAlignedSuffix_preservesWindowStartingAtLineBoundary() {
    let line1 = "[2026-09-06T08:24:01Z] diagnostic={\"event\":\"keep_b\"}\n"
    let line2 = "[2026-09-06T08:24:02Z] diagnostic={\"event\":\"keep_c\"}\n"
    let noise = "[2026-09-06T08:24:00Z] diagnostic={\"event\":\"noise_a\"}\n"
    let data = Data((noise + line1 + line2).utf8)
    let keepBytes = line1.utf8.count + line2.utf8.count
    let suffix = SyncLog.lineAlignedSuffix(from: data, keepBytes: keepBytes)
    let text = String(decoding: suffix, as: UTF8.self)
    #expect(text == line1 + line2)
}

@Test func syncLog_rotateAlignsToNewlineBoundary() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-sync-log-rotate-nl-\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: url) }

    let lineA = "[2026-09-06T08:24:00Z] diagnostic={\"event\":\"noise_a\"}\n"
    let lineB = "[2026-09-06T08:24:01Z] diagnostic={\"event\":\"keep_b\"}\n"
    let lineC = "[2026-09-06T08:24:02Z] diagnostic={\"event\":\"keep_c\"}\n"
    let padding = String(repeating: "X", count: SyncLog.maxFileBytes)
    let full = padding + lineA + lineB + lineC
    try Data(full.utf8).write(to: url)

    SyncLog.rotateIfNeeded(at: url)
    let text = try String(contentsOf: url, encoding: .utf8)
    #expect(!text.hasPrefix("X"))
    #expect(!text.hasPrefix("tion="))
    #expect(!text.hasPrefix("diagnostic="))
    #expect(text.first == "[" || text.isEmpty)
    #expect(text.contains("keep_b") || text.contains("keep_c"))
    #expect(text.utf8.count <= SyncLog.keepBytes)
}

@Test func diagnosticLogAttachment_previewPrefersNotableFailureLines() throws {
    let context = DiagnosticContext(runID: UUID(), providerID: .booking, operation: "startup_probe")
    func line(event: String, result: DiagnosticResult) throws -> String {
        let payload = String(
            decoding: try JSONEncoder().encode(
                DiagnosticEvent(
                    context: context,
                    component: "ProviderSessionView",
                    phase: "lifecycle",
                    event: event,
                    result: result
                )
            ),
            as: UTF8.self
        )
        return "[2026-09-05T12:51:39Z] diagnostic=\(payload)"
    }
    let noise = (0..<10).map { _ in
        (try? line(event: "webview_created", result: .succeeded)) ?? ""
    }
    let timeout = try line(event: "timeout", result: .timedOut)
    let text = (noise + [timeout]).joined(separator: "\n")
    let notable = DiagnosticLogCompressor.notablePreview(from: text, maxLineCount: 8)
    #expect(notable.contains("timeout"))
    #expect(notable.contains("timedOut"))
    #expect(notable.contains("booking"))
    #expect(!notable.contains("webview_created"))
    #expect(!notable.contains("diagnostic="))
}

@Test func syncLog_recentTailExcludesLocalDebugEventsByDefault() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-sync-log-visibility-\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: url) }

    let context = DiagnosticContext(runID: UUID(), providerID: .check24, operation: "test")
    let localEvent = String(
        decoding: try JSONEncoder().encode(
            DiagnosticEvent(
                context: context,
                component: "Test",
                phase: "dom",
                event: "dom_snapshot",
                result: .succeeded,
                visibility: .localDebugOnly
            )
        ),
        as: UTF8.self
    )
    let publicEvent = String(
        decoding: try JSONEncoder().encode(
            DiagnosticEvent(
                context: context,
                component: "Test",
                phase: "navigation",
                event: "navigation_failed",
                result: .failed
            )
        ),
        as: UTF8.self
    )
    try Data("""
    [2026-08-31T10:00:00Z] diagnostic=\(localEvent)
    [2026-08-31T10:00:01Z] diagnostic=\(publicEvent)
    """.utf8).write(to: url)

    let attachment = SyncLog.recentTail(fileURL: url)

    guard case .attached(let preview, _, _, _, _, _) = attachment else {
        Issue.record("expected attached log")
        return
    }
    #expect(!preview.contains("dom_snapshot"))
    #expect(preview.contains("navigation_failed"))
}

@Test func syncLog_removesExpiredDiagnosticEventsOnly() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-sync-log-expiry-\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: url) }

    let context = DiagnosticContext(runID: UUID(), providerID: .check24, operation: "test")
    let expired = String(
        decoding: try JSONEncoder().encode(
            DiagnosticEvent(
                timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                context: context,
                component: "Test",
                phase: "probe",
                event: "expired",
                result: .started,
                visibility: .localDebugOnly
            )
        ),
        as: UTF8.self
    )
    let current = String(
        decoding: try JSONEncoder().encode(
            DiagnosticEvent(
                timestamp: Date(timeIntervalSince1970: 1_700_100_000),
                context: context,
                component: "Test",
                phase: "probe",
                event: "current",
                result: .started,
                visibility: .localDebugOnly
            )
        ),
        as: UTF8.self
    )
    try Data("legacy\n[date] diagnostic=unknown-payload\n[date] diagnostic=\(expired)\n[date] diagnostic=\(current)\n".utf8)
        .write(to: url)

    try SyncLog.removeExpiredDiagnosticEvents(
        olderThan: Date(timeIntervalSince1970: 1_700_086_400),
        fileURL: url
    )

    let result = try String(contentsOf: url, encoding: .utf8)
    #expect(result.contains("legacy"))
    #expect(result.contains("unknown-payload"))
    #expect(!result.contains("expired"))
    #expect(result.contains("current"))
}

@Test func syncLog_recentTailDropsPartialFirstLineWhenTruncated() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-sync-log-partial-\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: url) }

    let context = DiagnosticContext(runID: UUID(), providerID: .check24, operation: "test")
    let localEvent = String(
        decoding: try JSONEncoder().encode(
            DiagnosticEvent(
                context: context,
                component: "Test",
                phase: "dom",
                event: "dom_snapshot_secret",
                result: .succeeded,
                visibility: .localDebugOnly
            )
        ),
        as: UTF8.self
    )
    let publicEvent = String(
        decoding: try JSONEncoder().encode(
            DiagnosticEvent(
                context: context,
                component: "Test",
                phase: "navigation",
                event: "navigation_ok",
                result: .succeeded
            )
        ),
        as: UTF8.self
    )
    let localLine = "[2026-08-31T10:00:00Z] diagnostic=\(localEvent)"
    let publicLine = "[2026-08-31T10:00:01Z] diagnostic=\(publicEvent)"
    let padding = String(repeating: "P", count: 200)
    let full = "\(padding)\n\(localLine)\n\(publicLine)\n"
    try Data(full.utf8).write(to: url)

    // Schneidet mitten in der localDebug-Zeile (nach "diagnostic="), ohne Marker am Fragment-Anfang.
    let cutInsideLocal = full.utf8.count - publicLine.utf8.count - 2 - (localLine.utf8.count / 2)
    let attachment = SyncLog.recentTail(maxBytes: cutInsideLocal, fileURL: url)

    guard case .attached(let preview, _, _, _, _, let truncated) = attachment else {
        Issue.record("expected attached log")
        return
    }
    #expect(truncated)
    #expect(!preview.contains("dom_snapshot_secret"))
    #expect(preview.contains("navigation_ok"))
}

@Test func syncLog_recentTailDropsEntireSuffixWhenTruncatedWithoutNewline() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-sync-log-no-nl-\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: url) }

    let context = DiagnosticContext(runID: UUID(), providerID: .check24, operation: "test")
    let localEvent = String(
        decoding: try JSONEncoder().encode(
            DiagnosticEvent(
                context: context,
                component: "Test",
                phase: "dom",
                event: "dom_snapshot_secret",
                result: .succeeded,
                visibility: .localDebugOnly
            )
        ),
        as: UTF8.self
    )
    let localLine = "[2026-08-31T10:00:00Z] diagnostic=\(localEvent)"
    try Data(localLine.utf8).write(to: url)

    let attachment = SyncLog.recentTail(maxBytes: localLine.utf8.count / 2, fileURL: url)
    guard case .attached(let preview, _, _, _, _, let truncated) = attachment else {
        Issue.record("expected attached log")
        return
    }
    #expect(truncated)
    #expect(preview.isEmpty)
    #expect(!preview.contains("dom_snapshot_secret"))
}
