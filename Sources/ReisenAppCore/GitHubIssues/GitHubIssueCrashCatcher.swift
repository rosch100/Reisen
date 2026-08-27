import Foundation
import ReisenData
import ReisenDomain

enum GitHubIssueCrashCatcher {
    private static var pendingURL: URL? {
        PersistenceBootstrap.supportDirectoryURL()?
            .appendingPathComponent("pending-crash-report.txt")
    }

    static func install() {
        previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(reisenUncaughtExceptionHandler)
    }

    static func appendPending(_ message: String) {
        guard let url = pendingURL else { return }
        writePending(message, to: url, optedIn: GitHubIssueAutoReport.isAutomaticReportingEnabled())
    }

    static func writePending(_ message: String, to url: URL, optedIn: Bool) {
        guard optedIn else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(message.utf8).write(to: url, options: [.atomic])
        } catch {
            #if DEBUG
            print("[Reisen] Pending-Crash-Report fehlgeschlagen: \(error)")
            #endif
        }
    }

    static func pendingMessageForReport(at url: URL, optedIn: Bool) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        if !optedIn {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    @MainActor
    static func flushPending() async {
        guard let url = pendingURL else { return }
        guard GitHubIssueAutoReport.isAutomaticReportingEnabled() else {
            _ = pendingMessageForReport(at: url, optedIn: false)
            return
        }
        guard let message = pendingMessageForReport(at: url, optedIn: true), !message.isEmpty else {
            return
        }
        do {
            _ = try await GitHubIssueReporter.shared.report(
                kind: .error,
                message: message,
                providerID: nil,
                titleOverride: GitHubIssueTitle.uncaughtException
            )
            try FileManager.default.removeItem(at: url)
        } catch is GitHubIssueTokenError {
            return
        } catch {
            #if DEBUG
            print("[Reisen] Pending-Crash-Issue nicht gesendet, Datei bleibt: \(error.localizedDescription)")
            #endif
        }
    }
}

/// Darwin-Uncaught-Handler ist prozessweit und nicht Swift-isolated; C-ABI braucht Speicher ohne Capture.
nonisolated(unsafe) private var previousUncaughtExceptionHandler: NSUncaughtExceptionHandler?

/// C-ABI: `NSSetUncaughtExceptionHandler` akzeptiert keine Closure mit Capture.
private func reisenUncaughtExceptionHandler(_ exception: NSException) {
    let reason = exception.reason ?? ""
    let stack = exception.callStackSymbols.joined(separator: "\n")
    GitHubIssueCrashCatcher.appendPending("\(exception.name.rawValue): \(reason)\n\(stack)")
    previousUncaughtExceptionHandler?(exception)
}
