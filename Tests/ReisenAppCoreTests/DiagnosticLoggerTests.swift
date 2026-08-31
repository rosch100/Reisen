import Foundation
import Testing
import ReisenDomain
@testable import ReisenAppCore

@Test func diagnosticLogger_writesPublicEventsAsJSONLines() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-diagnostic-log-\(UUID().uuidString).jsonl")
    defer { try? FileManager.default.removeItem(at: url) }

    let logger = DiagnosticLogger(fileURL: url, debugEnabled: false)
    let event = DiagnosticEvent(
        context: DiagnosticContext(runID: UUID(), providerID: .check24, operation: "startup_probe"),
        component: "Probe",
        phase: "navigation",
        event: "did_finish",
        result: .succeeded
    )

    await logger.record(event)
    await logger.flush()

    let data = try Data(contentsOf: url)
    let lines = String(decoding: data, as: UTF8.self).split(separator: "\n")
    #expect(lines.count == 1)
    let payload = try #require(lines[0].split(separator: "] ", maxSplits: 1).last)
        .dropFirst("diagnostic=".count)
    #expect(try JSONDecoder().decode(DiagnosticEvent.self, from: Data(payload.utf8)) == event)
}

@Test func diagnosticLogger_excludesLocalDebugEventsUnlessEnabled() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-diagnostic-log-\(UUID().uuidString).jsonl")
    defer { try? FileManager.default.removeItem(at: url) }

    let logger = DiagnosticLogger(fileURL: url, debugEnabled: false)
    let event = DiagnosticEvent(
        context: DiagnosticContext(runID: UUID(), providerID: .check24, operation: "auto_login"),
        component: "Login",
        phase: "dom",
        event: "fields",
        result: .succeeded,
        visibility: .localDebugOnly
    )

    await logger.record(event)
    await logger.flush()

    #expect(!FileManager.default.fileExists(atPath: url.path))
}

@Test func diagnosticLogger_writesLocalDebugEventsWhenEnabled() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-diagnostic-log-\(UUID().uuidString).jsonl")
    defer { try? FileManager.default.removeItem(at: url) }

    let logger = DiagnosticLogger(fileURL: url, debugEnabled: true)
    let event = DiagnosticEvent(
        context: DiagnosticContext(runID: UUID(), providerID: .check24, operation: "auto_login"),
        component: "Login",
        phase: "dom",
        event: "fields",
        result: .succeeded,
        visibility: .localDebugOnly
    )

    await logger.record(event)
    await logger.flush()

    #expect(FileManager.default.fileExists(atPath: url.path))
}

@Test func diagnosticLogger_sanitizesRawEventURLs() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-diagnostic-log-\(UUID().uuidString).jsonl")
    defer { try? FileManager.default.removeItem(at: url) }

    let logger = DiagnosticLogger(fileURL: url, debugEnabled: false)
    await logger.record(
        DiagnosticEvent(
            context: DiagnosticContext(runID: UUID(), providerID: .check24, operation: "test"),
            component: "Test",
            phase: "navigation",
            event: "url",
            result: .succeeded,
            url: "https://kundenbereich.check24.de/login?token=secret#fragment"
        )
    )
    await logger.flush()

    let text = try String(contentsOf: url, encoding: .utf8)
    #expect(!text.contains("token=secret"))
    #expect(!text.contains("fragment"))
    let payload = try #require(text.split(separator: "] ", maxSplits: 1).last)
        .dropFirst("diagnostic=".count)
    let decoded = try JSONDecoder().decode(
        DiagnosticEvent.self,
        from: Data(payload.utf8)
    )
    #expect(decoded.url == "kundenbereich.check24.de")
}

@Test func diagnosticLogger_rateLimitsIdenticalEvents() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-diagnostic-log-\(UUID().uuidString).jsonl")
    defer { try? FileManager.default.removeItem(at: url) }

    let logger = DiagnosticLogger(fileURL: url, debugEnabled: false)
    let event = DiagnosticEvent(
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        context: DiagnosticContext(runID: UUID(), providerID: .check24, operation: "startup_probe"),
        component: "Probe",
        phase: "navigation",
        event: "did_commit",
        result: .started
    )

    for _ in 0...100 {
        await logger.record(event)
    }
    await logger.flush()

    let text = try String(contentsOf: url, encoding: .utf8)
    #expect(text.split(separator: "\n").count == 101)
    #expect(text.contains("repeated_events"))
}

@Test func diagnosticLogger_doesNotEmitEmptyRepeatSummary() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-diagnostic-log-\(UUID().uuidString).jsonl")
    defer { try? FileManager.default.removeItem(at: url) }

    let logger = DiagnosticLogger(fileURL: url, debugEnabled: false)
    let context = DiagnosticContext(runID: UUID(), providerID: .check24, operation: "test")
    await logger.record(
        DiagnosticEvent(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            context: context,
            component: "Probe",
            phase: "test",
            event: "single",
            result: .started
        )
    )
    await logger.record(
        DiagnosticEvent(
            timestamp: Date(timeIntervalSince1970: 1_700_000_011),
            context: context,
            component: "Probe",
            phase: "test",
            event: "single",
            result: .started
        )
    )
    await logger.flush()

    let text = try String(contentsOf: url, encoding: .utf8)
    #expect(text.split(separator: "\n").count == 2)
    #expect(!text.contains("repeated_events"))
}

@Test func diagnosticLogger_reportsBackpressureWhenQueueIsFull() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-diagnostic-log-\(UUID().uuidString).jsonl")
    defer { try? FileManager.default.removeItem(at: url) }

    let logger = DiagnosticLogger(fileURL: url, debugEnabled: false, maxQueueSize: 1)
    await withTaskGroup(of: Void.self) { group in
        for index in 0..<20 {
            group.addTask {
                await logger.record(
                    DiagnosticEvent(
                        context: DiagnosticContext(runID: UUID(), providerID: .check24, operation: "test"),
                        component: "Test",
                        phase: "queue",
                        event: "event_\(index)",
                        result: .started
                    )
                )
            }
        }
    }
    await logger.flush()

    let text = try String(contentsOf: url, encoding: .utf8)
    #expect(text.contains("log_backpressure"))
}
