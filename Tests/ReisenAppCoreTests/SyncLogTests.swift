import Testing
import Foundation
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
    guard case .attached(let preview, _, _, let fileByteCount, let truncated) = attachment else {
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
    let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber
    #expect(size?.intValue == SyncLog.keepBytes)
}
