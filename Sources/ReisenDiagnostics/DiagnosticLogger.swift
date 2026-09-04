import Foundation
import OSLog

public actor DiagnosticLogger {
    public static let shared = DiagnosticLogger()

    private let fileURL: URL?
    private let debugEnabled: Bool
    private let maxQueueSize: Int
    private let logger = Logger(
        subsystem: "de.roschmac.Reisen",
        category: "diagnostics"
    )
    private var recentEvents: [RateLimitKey: RateLimitEntry] = [:]
    private var didCleanupExpiredEvents = false
    private var queue: [DiagnosticEvent] = []
    private var isDraining = false
    private var droppedEventCount = 0
    private var backpressureSource: DiagnosticEvent?

    public init(
        fileURL: URL? = nil,
        debugEnabled: Bool? = nil,
        maxQueueSize: Int = 256
    ) {
        self.fileURL = fileURL
#if DEBUG
        self.debugEnabled = debugEnabled
            ?? ProcessInfo.processInfo.arguments.contains("-ReisenDiagnosticsDebug")
#else
        self.debugEnabled = false
#endif
        self.maxQueueSize = max(1, maxQueueSize)
    }

    public func record(_ event: DiagnosticEvent) async {
        guard event.visibility == .publicDiagnostic || debugEnabled else { return }
        cleanupExpiredEventsIfNeeded(at: event.timestamp)
        let sanitized = sanitizedEvent(event)
        let key = RateLimitKey(event: sanitized)
        if let existing = recentEvents[key] {
            if event.timestamp.timeIntervalSince(existing.start) > Self.rateLimitWindow {
                if existing.suppressed > 0 {
                    enqueue(repeatedEvent(for: existing))
                }
                recentEvents[key] = RateLimitEntry(
                    start: event.timestamp,
                    count: 1,
                    suppressed: 0,
                    source: sanitized
                )
            } else if existing.count >= Self.rateLimitLimit {
                recentEvents[key] = RateLimitEntry(
                    start: existing.start,
                    count: existing.count,
                    suppressed: existing.suppressed + 1,
                    source: existing.source
                )
                return
            } else {
                recentEvents[key] = RateLimitEntry(
                    start: existing.start,
                    count: existing.count + 1,
                    suppressed: existing.suppressed,
                    source: existing.source
                )
            }
        } else {
            recentEvents[key] = RateLimitEntry(
                start: event.timestamp,
                count: 1,
                suppressed: 0,
                source: sanitized
            )
        }
        enqueue(sanitized)
        scheduleDrain()
    }

    public func flush() async {
        scheduleDrain()
        while isDraining {
            await Task.yield()
        }
        for entry in recentEvents.values where entry.suppressed > 0 {
            write(repeatedEvent(for: entry))
        }
        recentEvents.removeAll()
    }

    private func enqueue(_ event: DiagnosticEvent) {
        guard queue.count < maxQueueSize else {
            droppedEventCount += 1
            backpressureSource = backpressureSource ?? event
            return
        }
        queue.append(event)
    }

    private func scheduleDrain() {
        guard !isDraining else { return }
        isDraining = true
        Task { await self.drainQueue() }
    }

    private func drainQueue() async {
        while !queue.isEmpty {
            write(queue.removeFirst())
            await Task.yield()
        }
        isDraining = false
        guard droppedEventCount > 0, let source = backpressureSource else { return }
        let count = droppedEventCount
        droppedEventCount = 0
        backpressureSource = nil
        write(
            DiagnosticEvent(
                timestamp: Date(),
                context: source.context,
                component: "DiagnosticLogger",
                phase: "sink",
                event: "log_backpressure",
                result: .failed,
                attempt: count,
                reason: "events_dropped",
                visibility: source.visibility
            )
        )
        if !queue.isEmpty {
            scheduleDrain()
        }
    }

    private func write(_ event: DiagnosticEvent) {
        guard let data = try? JSONEncoder().encode(event) else {
            logger.error("Diagnoseevent konnte nicht serialisiert werden.")
            return
        }
        let line = "diagnostic=\(String(decoding: data, as: UTF8.self))"
        logger.debug("\(line, privacy: .private)")
        guard SyncLog.append(line, to: fileURL ?? SyncLog.fileURL(), now: event.timestamp) else {
            logger.error("Diagnoseevent konnte nicht persistiert werden.")
            return
        }
    }

    private func cleanupExpiredEventsIfNeeded(at now: Date) {
        guard debugEnabled, !didCleanupExpiredEvents else { return }
        didCleanupExpiredEvents = true
        guard let destination = fileURL ?? SyncLog.fileURL() else {
            logger.error("Diagnose-Sink ist nicht verfügbar.")
            return
        }
        do {
            try SyncLog.removeExpiredDiagnosticEvents(
                olderThan: now.addingTimeInterval(-24 * 60 * 60),
                fileURL: destination
            )
        } catch {
            logger.error("Abgelaufene Diagnoseevents konnten nicht gelöscht werden.")
        }
    }

    private func sanitizedEvent(_ event: DiagnosticEvent) -> DiagnosticEvent {
        DiagnosticEvent(
            timestamp: event.timestamp,
            context: event.context,
            component: DiagnosticRedactor.redact(event.component),
            phase: DiagnosticRedactor.redact(event.phase),
            event: DiagnosticRedactor.redact(event.event),
            result: event.result,
            attempt: event.attempt,
            durationMilliseconds: event.durationMilliseconds,
            url: event.url.flatMap(DiagnosticRedactor.urlMetadata(for:)),
            errorType: event.errorType.map(DiagnosticRedactor.redact),
            reason: event.reason.map(DiagnosticRedactor.redact),
            statusBefore: event.statusBefore.map(DiagnosticRedactor.redact),
            statusAfter: event.statusAfter.map(DiagnosticRedactor.redact),
            visibility: event.visibility
        )
    }

    private static let rateLimitWindow: TimeInterval = 10
    private static let rateLimitLimit = 100

    private struct RateLimitKey: Hashable {
        let providerID: String
        let component: String
        let phase: String
        let event: String
        let url: String?
        let reason: String?

        init(event: DiagnosticEvent) {
            providerID = event.context.providerID.rawValue
            component = event.component
            phase = event.phase
            self.event = event.event
            url = event.url
            reason = event.reason
        }
    }

    private struct RateLimitEntry {
        let start: Date
        let count: Int
        let suppressed: Int
        let source: DiagnosticEvent
    }

    private func repeatedEvent(for entry: RateLimitEntry) -> DiagnosticEvent {
        DiagnosticEvent(
            timestamp: entry.source.timestamp,
            context: entry.source.context,
            component: entry.source.component,
            phase: entry.source.phase,
            event: "repeated_events",
            result: .succeeded,
            attempt: entry.suppressed,
            durationMilliseconds: nil,
            url: entry.source.url,
            errorType: nil,
            reason: "suppressed_events",
            statusBefore: nil,
            statusAfter: nil,
            visibility: entry.source.visibility
        )
    }
}
