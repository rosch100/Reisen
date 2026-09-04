import Foundation
import OSLog
import ReisenDomain

public enum SyncLog {
    public static let maxFileBytes = 262_144
    public static let keepBytes = 65_536
    private static let fileAccessLock = NSLock()
    private static let logger = Logger(
        subsystem: "app.voyenna.reisen",
        category: "sync-log"
    )

    public static func fileURL() -> URL? {
        ReisenApplicationSupport.directoryURL()?
            .appendingPathComponent("sync-log.txt")
    }

    @discardableResult
    public static func append(_ line: String) -> Bool {
        append(line, to: fileURL(), now: Date())
    }

    @discardableResult
    public static func append(_ line: String, to url: URL?, now: Date) -> Bool {
        fileAccessLock.lock()
        defer { fileAccessLock.unlock() }
        let fm = FileManager.default
        guard let logURL = url else {
            logger.error("Sync-Log-Ziel ist nicht verfügbar.")
            return false
        }
        let base = logURL.deletingLastPathComponent()
        do {
            try fm.createDirectory(at: base, withIntermediateDirectories: true)
            let fullLine = "[\(ISO8601DateFormatter().string(from: now))] \(line)\n"
            guard let data = fullLine.data(using: .utf8) else {
                logger.error("Sync-Log konnte nicht als UTF-8 kodiert werden.")
                return false
            }
            if fm.fileExists(atPath: logURL.path) {
                let handle = try FileHandle(forWritingTo: logURL)
                defer {
                    do {
                        try handle.close()
                    } catch {
                        logger.error("Sync-Log-Datei konnte nicht geschlossen werden.")
                    }
                }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: logURL, options: [.atomic])
            }
            return rotateIfNeeded(at: logURL)
        } catch {
            logger.error(
                "Sync-Log fehlgeschlagen: \(error.localizedDescription, privacy: .private)"
            )
            return false
        }
    }

    @discardableResult
    public static func rotateIfNeeded(at url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            guard data.count > maxFileBytes else { return true }
            let suffix = data.suffix(keepBytes)
            try suffix.write(to: url, options: [.atomic])
            return true
        } catch {
            logger.error(
                "Sync-Log-Rotation fehlgeschlagen: \(error.localizedDescription, privacy: .private)"
            )
            return false
        }
    }

    public static func removeExpiredDiagnosticEvents(
        olderThan cutoff: Date,
        fileURL: URL
    ) throws {
        fileAccessLock.lock()
        defer { fileAccessLock.unlock() }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let retainedLines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { line in
                guard let markerRange = line.range(of: "diagnostic=") else { return true }
                let payload = line[markerRange.upperBound...]
                guard let data = payload.data(using: .utf8),
                      let event = try? JSONDecoder().decode(DiagnosticEvent.self, from: data)
                else {
                    return true
                }
                return event.timestamp >= cutoff
            }
        try Data(retainedLines.joined(separator: "\n").utf8)
            .write(to: fileURL, options: [.atomic])
    }
}
