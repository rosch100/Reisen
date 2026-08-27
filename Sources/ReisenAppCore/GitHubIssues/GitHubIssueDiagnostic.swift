import Darwin
import Foundation
import ReisenDomain

public enum GitHubIssueDiagnostic {
    public static func body(
        kind: GitHubIssueKind,
        title: String,
        message: String,
        providerID: ProviderID?,
        origin: GitHubIssueReportOrigin,
        appVersion: String,
        build: String,
        os: String,
        device: String,
        locale: String,
        timeZone: String,
        fingerprint: String
    ) -> String {
        let redactedMessage = SecretRedactor.redact(message)
        let redactedTitle = SecretRedactor.redact(title)
        return """
        ## Zusammenfassung
        \(redactedTitle)

        \(diagnosticTable(
            kind: kind,
            providerID: providerID,
            origin: origin,
            appVersion: appVersion,
            build: build,
            os: os,
            device: device,
            locale: locale,
            timeZone: timeZone,
            fingerprint: fingerprint
        ))

        ## \(kind.messageSectionTitle)
        ```
        \(redactedMessage)
        ```
        """
    }

    /// Inhalt für vorausgefüllte Issue-Formularfelder (`what` / `feedback`) ohne Titel-Dopplung.
    public static func collectedFormFieldContent(
        kind: GitHubIssueKind,
        message: String,
        providerID: ProviderID?,
        origin: GitHubIssueReportOrigin
    ) -> String {
        let redactedMessage = SecretRedactor.redact(message)
        let appendix = diagnosticAppendix(
            kind: kind,
            message: message,
            providerID: providerID,
            origin: origin
        )
        guard !appendix.isEmpty else { return redactedMessage }
        return """
        \(redactedMessage)

        ---

        \(appendix)
        """
    }

    public static func collectedBody(
        kind: GitHubIssueKind,
        title: String,
        message: String,
        providerID: ProviderID?,
        origin: GitHubIssueReportOrigin = .embeddedToken(attributedUsername: nil)
    ) -> String {
        let fingerprint = GitHubIssueFingerprint.hex(kind: kind, message: SecretRedactor.redact(message))
        let bundle = Bundle.main
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return body(
            kind: kind,
            title: title,
            message: message,
            providerID: providerID,
            origin: origin,
            appVersion: appVersion,
            build: build,
            os: ProcessInfo.processInfo.operatingSystemVersionString,
            device: deviceModel(),
            locale: Locale.current.identifier,
            timeZone: TimeZone.current.identifier,
            fingerprint: fingerprint
        )
    }

    private static func diagnosticAppendix(
        kind: GitHubIssueKind,
        message: String,
        providerID: ProviderID?,
        origin: GitHubIssueReportOrigin
    ) -> String {
        let fingerprint = GitHubIssueFingerprint.hex(kind: kind, message: SecretRedactor.redact(message))
        let bundle = Bundle.main
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return diagnosticTable(
            kind: kind,
            providerID: providerID,
            origin: origin,
            appVersion: appVersion,
            build: build,
            os: ProcessInfo.processInfo.operatingSystemVersionString,
            device: deviceModel(),
            locale: Locale.current.identifier,
            timeZone: TimeZone.current.identifier,
            fingerprint: fingerprint
        )
    }

    private static func diagnosticTable(
        kind: GitHubIssueKind,
        providerID: ProviderID?,
        origin: GitHubIssueReportOrigin,
        appVersion: String,
        build: String,
        os: String,
        device: String,
        locale: String,
        timeZone: String,
        fingerprint: String
    ) -> String {
        let provider = providerID.map(\.displayName) ?? "—"
        return """
        ## Diagnose
        | Feld | Wert |
        | --- | --- |
        | Art | \(kind.displayName) |
        | Quelle | \(kind.sourceLabel) |
        | Meldeweg | \(origin.meldewegLabel) |
        | GitHub-Nutzer | \(origin.githubUserLabel) |
        | App | \(appVersion) (\(build)) |
        | Betriebssystem | \(os) |
        | Gerät | \(device) |
        | Sprache | \(locale) |
        | Zeitzone | \(timeZone) |
        | Provider | \(provider) |

        reisen-fingerprint: `\(fingerprint)`
        <!-- reisen-fingerprint: \(fingerprint) -->
        """
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
