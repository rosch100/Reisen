import Foundation
import ReisenCrashSignal
import ReisenDiagnostics
import ReisenDomain

enum GitHubIssueCrashReport {
    static let postCrashRelaunchLabel = "Neustart nach Absturz"
    /// Diagnose-Context wenn der Pending-Text keinen `provider=` hat — nicht `.manual`.
    static let flushProviderUnknown = ProviderID(rawValue: "none")
    private static let providerFieldPrefix = "provider="
    private static let imageOffsetPrefix = "+0x"
    private static let unknownSignalPrefix = "SIGNAL "
    private static let fatalSignalNames: Set<String> = [
        "SIGTRAP", "SIGABRT", "SIGSEGV", "SIGBUS", "SIGILL", "SIGFPE",
    ]

    static func reportTitle(from message: String) -> String {
        let first = firstLine(message)
        if isFatalSignalLine(first) {
            return GitHubIssueTitle.reportTitle(kind: .error, message: first)
        }
        return GitHubIssueTitle.uncaughtException
    }

    static func providerID(from message: String) -> ProviderID? {
        for line in message.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(providerFieldPrefix) else { continue }
            let raw = String(trimmed.dropFirst(providerFieldPrefix.count))
            let token = raw.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? raw
            guard !token.isEmpty else { return nil }
            return ProviderID(rawValue: token)
        }
        return nil
    }

    static func fingerprintMaterial(from message: String) -> String {
        let lines = message.split(whereSeparator: \.isNewline)
        var parts: [String] = []
        if let first = lines.first {
            parts.append(String(first))
        }
        for line in lines {
            if let annotated = imageOffsetToken(from: String(line)) {
                parts.append(annotated)
            }
        }
        return parts.joined(separator: "\n")
    }

    static func breadcrumbLine(from event: DiagnosticEvent) -> String {
        var parts = [
            "\(providerFieldPrefix)\(event.context.providerID.rawValue)",
            "component=\(event.component)",
            "phase=\(event.phase)",
            "event=\(event.event)",
            "result=\(event.result.rawValue)",
        ]
        if let reason = event.reason, !reason.isEmpty {
            parts.append("reason=\(reason)")
        }
        return parts.joined(separator: " ")
    }

    static func shouldNote(_ event: DiagnosticEvent) -> Bool {
        guard event.visibility == .publicDiagnostic else { return false }
        if event.result != .succeeded { return true }
        switch event.event {
        case "webview_created", "webview_reparented":
            return false
        default:
            return true
        }
    }

    static func note(_ event: DiagnosticEvent) {
        guard shouldNote(event) else { return }
        event.context.providerID.rawValue.withCString { reisen_crash_signal_note_provider($0) }
        breadcrumbLine(from: event).withCString { reisen_crash_signal_note_breadcrumb($0) }
    }

    private static func isFatalSignalLine(_ line: String) -> Bool {
        fatalSignalNames.contains(line) || line.hasPrefix(unknownSignalPrefix)
    }

    private static func firstLine(_ message: String) -> String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? ""
    }

    private static func imageOffsetToken(from line: String) -> String? {
        let parts = line.split(separator: " ")
        guard parts.count >= 3, parts[2].hasPrefix(imageOffsetPrefix) else { return nil }
        return "\(parts[1]) \(parts[2])"
    }
}
