import Darwin
import Foundation
import ReisenDomain

public enum GitHubIssueDiagnostic {
    private static let maxExtraSectionCharacters = 12_000
    private static let formFieldSeparator = "\n\n---\n\n"

    struct DeviceDiagnostics {
        let fingerprint: String
        let appVersion: String
        let build: String
        let os: String
        let device: String
        let locale: String
        let timeZone: String
        let environment: RuntimeEnvironmentSnapshot
        let logAttachment: DiagnosticLogAttachment
    }

    static func body(
        kind: GitHubIssueKind,
        title: String,
        message: String,
        providerID: ProviderID?,
        origin: GitHubIssueReportOrigin,
        diagnostics: DeviceDiagnostics,
        technicalDetails: String? = nil,
        includeCompressedLog: Bool = true
    ) -> String {
        clampToGitHubAPIBodyLimit(
            """
            \(GitHubIssueMarkdown.sectionHeading("Zusammenfassung"))
            \(SecretRedactor.redact(title))

            \(diagnosticTable(kind: kind, providerID: providerID, origin: origin, diagnostics: diagnostics))

            \(GitHubIssueMarkdown.sectionHeading(kind.displayName))
            \(fencedRedacted(message))
            \(extraSection(heading: "Technische Details", text: technicalDetails))
            \(diagnostics.logAttachment.markdownSection(includeCompressedLog: includeCompressedLog))
            """
        )
    }

    /// Inhalt für vorausgefüllte Issue-Formularfelder (`what` / `feedback`) ohne Titel-Dopplung.
    static func collectedFormFieldContent(
        kind: GitHubIssueKind,
        message: String,
        providerID: ProviderID?,
        origin: GitHubIssueReportOrigin,
        diagnostics: DeviceDiagnostics? = nil,
        shrinkingWhile shouldShrink: ((String) -> Bool)? = nil,
        minimumFencedCharacters: Int = 0,
        step: Int = 1
    ) -> String {
        let parts = formFieldParts(
            kind: kind,
            message: message,
            providerID: providerID,
            origin: origin,
            diagnostics: diagnostics
        )
        var budget = max(minimumFencedCharacters, parts.tableAwareBudget)
        var value = parts.value(fencedBudget: budget)
        guard let shouldShrink else { return value }
        while shouldShrink(value) && budget > minimumFencedCharacters {
            budget = max(minimumFencedCharacters, budget - step)
            value = parts.value(fencedBudget: budget)
        }
        return value
    }

    private struct FormFieldParts {
        let redactedMessage: String
        let table: String

        var tableAwareBudget: Int {
            max(
                0,
                GitHubIssueNewIssueURL.maxBodyCharacterCount - table.count
                    - GitHubIssueDiagnostic.formFieldSeparator.count
            )
        }

        func value(fencedBudget: Int) -> String {
            GitHubIssueMarkdown.fenceFitting(redactedMessage, maxCharacters: fencedBudget)
                + GitHubIssueDiagnostic.formFieldSeparator
                + table
        }
    }

    private static func formFieldParts(
        kind: GitHubIssueKind,
        message: String,
        providerID: ProviderID?,
        origin: GitHubIssueReportOrigin,
        diagnostics: DeviceDiagnostics?
    ) -> FormFieldParts {
        let redactedMessage = SecretRedactor.redact(message)
        let snapshot = diagnostics ?? deviceSnapshot(kind: kind, redactedMessage: redactedMessage)
        return FormFieldParts(
            redactedMessage: redactedMessage,
            table: diagnosticTable(
                kind: kind,
                providerID: providerID,
                origin: origin,
                diagnostics: snapshot
            )
        )
    }

    static func deviceSnapshot(kind: GitHubIssueKind, redactedMessage: String) -> DeviceDiagnostics {
        let bundle = Bundle.main
        return DeviceDiagnostics(
            fingerprint: GitHubIssueFingerprint.hex(kind: kind, message: redactedMessage),
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—",
            os: ProcessInfo.processInfo.operatingSystemVersionString,
            device: deviceModel(),
            locale: Locale.current.identifier,
            timeZone: TimeZone.current.identifier,
            environment: .live(),
            logAttachment: SyncLog.recentTail()
        )
    }

    private static func diagnosticTable(
        kind: GitHubIssueKind,
        providerID: ProviderID?,
        origin: GitHubIssueReportOrigin,
        diagnostics: DeviceDiagnostics
    ) -> String {
        let provider = providerID.map(\.displayName) ?? "—"
        return """
        \(GitHubIssueMarkdown.sectionHeading("Diagnose"))
        | Feld | Wert |
        | --- | --- |
        | Art | \(kind.displayName) |
        | Quelle | \(kind.sourceLabel) |
        | Meldeweg | \(origin.meldewegLabel) |
        | GitHub-Nutzer | \(origin.githubUserLabel) |
        | App | \(diagnostics.appVersion) (\(diagnostics.build)) |
        | Betriebssystem | \(diagnostics.os) |
        | Gerät | \(diagnostics.device) |
        | Sprache | \(diagnostics.locale) |
        | Zeitzone | \(diagnostics.timeZone) |
        \(diagnostics.environment.tableRows().trimmingCharacters(in: .newlines))
        | Provider | \(provider) |
        | Dateianhänge | \(GitHubRepository.issueAttachmentPolicyCell) |

        reisen-fingerprint: `\(diagnostics.fingerprint)`
        <!-- reisen-fingerprint: \(diagnostics.fingerprint) -->
        """
    }

    static func clampToGitHubAPIBodyLimit(_ body: String) -> String {
        let maxBodyLength = GitHubRepository.issueBodyMaxLength
        guard body.count > maxBodyLength else { return body }
        let suffix = "\n\n" + GitHubRepository.issueBodyTruncationNotice
        let keep = max(0, maxBodyLength - suffix.count)
        return GitHubIssueMarkdown.prefixFittingSectionHeadings(body, maxCharacters: keep) + suffix
    }

    private static func extraSection(heading: String, text: String?) -> String {
        guard let text else { return "" }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return """

        \(GitHubIssueMarkdown.sectionHeading(heading))
        \(fencedRedacted(trimmed, clipTo: maxExtraSectionCharacters))
        """
    }

    private static func fencedRedacted(_ text: String, clipTo maxCharacters: Int? = nil) -> String {
        let redacted = SecretRedactor.redact(text)
        let clipped = maxCharacters.map { clip(redacted, to: $0) } ?? redacted
        return GitHubIssueMarkdown.fence(clipped)
    }

    private static func clip(_ value: String, to maxCharacters: Int) -> String {
        guard value.count > maxCharacters else { return value }
        return String(value.prefix(maxCharacters)) + "\n… (gekürzt)"
    }

    private static func deviceModel() -> String {
        #if os(macOS)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let bytes = model.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        #endif
    }
}
