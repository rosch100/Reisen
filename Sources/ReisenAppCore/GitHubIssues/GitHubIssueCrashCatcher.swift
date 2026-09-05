import Darwin
import Foundation
import ReisenCrashSignal
import ReisenData
import ReisenDomain
import ReisenDiagnostics

enum GitHubIssueCrashCatcher {
    private static var pendingURL: URL? {
        PersistenceBootstrap.supportDirectoryURL()?
            .appendingPathComponent("pending-crash-report.txt")
    }

    static func install() {
        previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(reisenUncaughtExceptionHandler)
        if let url = pendingURL {
            prepareFatalSignalPending(
                at: url,
                optedIn: GitHubIssueAutoReport.isAutomaticReportingEnabled()
            )
        }
        _ = reisen_crash_signal_install(isDebuggerAttached())
        startObservingAutomaticReportingOptIn()
    }

    static func refreshFatalSignalOptIn() {
        reisen_crash_signal_set_opted_in(GitHubIssueAutoReport.isAutomaticReportingEnabled())
    }

    private static func startObservingAutomaticReportingOptIn() {
        guard fatalSignalOptInObserver == nil else { return }
        fatalSignalOptInObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { _ in
            GitHubIssueCrashCatcher.refreshFatalSignalOptIn()
        }
    }

    static func prepareFatalSignalPending(at url: URL, optedIn: Bool) {
        try? ensureParentDirectory(for: url)
        _ = reisen_crash_signal_prepare(url.path, optedIn)
    }

    static func message(from exception: NSException) -> String {
        let reason = exception.reason ?? ""
        let stack = exception.callStackSymbols.joined(separator: "\n")
        var text = "\(exception.name.rawValue): \(reason)\n\(stack)"
        let dumped = diagnosticUserInfoLines(exception.userInfo)
        if !dumped.isEmpty {
            text += "\nuserInfo:\n" + dumped.joined(separator: "\n")
        }
        return text
    }

    private static func diagnosticUserInfoLines(_ info: [AnyHashable: Any]?) -> [String] {
        guard let info, !info.isEmpty else { return [] }
        return GitHubIssueErrorText.userInfoKeys.compactMap { key in
            guard let value = info[key] else { return nil }
            return diagnosticLine(key: key, value: value)
        }
    }

    private static func diagnosticLine(key: String, value: Any) -> String? {
        if key == NSUnderlyingErrorKey {
            guard let error = value as? NSError else { return nil }
            return "Underlying: \(error.domain) \(error.code) \(error.localizedDescription)"
        }
        if key == NSURLErrorKey, let url = GitHubIssueErrorText.urlText(value) {
            return "URL: \(url)"
        }
        guard let text = value as? String, !text.isEmpty else { return nil }
        return "\(key): \(text)"
    }

    static func appendPending(_ message: String) {
        guard let url = pendingURL else { return }
        if writePending(message, to: url, optedIn: GitHubIssueAutoReport.isAutomaticReportingEnabled()) {
            reisen_crash_signal_mark_written()
        }
    }

    @discardableResult
    static func writePending(_ message: String, to url: URL, optedIn: Bool) -> Bool {
        guard optedIn else { return false }
        do {
            try ensureParentDirectory(for: url)
            try Data(SecretRedactor.redact(message).utf8).write(to: url, options: [.atomic])
            return true
        } catch {
            // Crash-/Uncaught-Pfad: kein async Diagnostic; Fail = return false.
            return false
        }
    }

    private static func ensureParentDirectory(for url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    static func pendingMessageForReport(at url: URL, optedIn: Bool) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        if !optedIn {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return SecretRedactor.redact(raw)
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
                titleOverride: GitHubIssueTitle.uncaughtException,
                reporterGitHubUsername: AppSettingsKeys.optionalFeedbackGitHubUsername()
            )
            try FileManager.default.removeItem(at: url)
        } catch is GitHubIssueTokenError {
            return
        } catch {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .manual,
                        operation: "github_crash_flush"
                    ),
                    component: "GitHubIssueCrashCatcher",
                    phase: "flush",
                    event: "pending_crash_report",
                    result: .failed,
                    reason: String(describing: type(of: error)),
                    visibility: .publicDiagnostic
                )
            )
        }
    }

    static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let sysctlResult = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        return sysctlResult == 0 && (info.kp_proc.p_flag & P_TRACED) != 0
    }
}

/// Darwin-Uncaught-Handler ist prozessweit und nicht Swift-isolated; C-ABI braucht Speicher ohne Capture.
nonisolated(unsafe) private var previousUncaughtExceptionHandler: NSUncaughtExceptionHandler?
nonisolated(unsafe) private var fatalSignalOptInObserver: (any NSObjectProtocol)?

/// C-ABI: `NSSetUncaughtExceptionHandler` akzeptiert keine Closure mit Capture.
private func reisenUncaughtExceptionHandler(_ exception: NSException) {
    GitHubIssueCrashCatcher.appendPending(GitHubIssueCrashCatcher.message(from: exception))
    previousUncaughtExceptionHandler?(exception)
}
