import Darwin
import Foundation
import ReisenDomain

public enum GitHubIssueDiagnostic {
    struct DeviceDiagnostics {
        let fingerprint: String
        let appVersion: String
        let build: String
        let os: String
        let device: String
        let locale: String
        let timeZone: String
    }

    static func body(
        kind: GitHubIssueKind,
        title: String,
        message: String,
        providerID: ProviderID?,
        origin: GitHubIssueReportOrigin,
        diagnostics: DeviceDiagnostics
    ) -> String {
        """
        ## Zusammenfassung
        \(SecretRedactor.redact(title))

        \(diagnosticTable(kind: kind, providerID: providerID, origin: origin, diagnostics: diagnostics))

        ## \(kind.displayName)
        ```
        \(SecretRedactor.redact(message))
        ```
        """
    }

    /// Inhalt für vorausgefüllte Issue-Formularfelder (`what` / `feedback`) ohne Titel-Dopplung.
    static func collectedFormFieldContent(
        kind: GitHubIssueKind,
        message: String,
        providerID: ProviderID?,
        origin: GitHubIssueReportOrigin
    ) -> String {
        let redactedMessage = SecretRedactor.redact(message)
        return """
        \(redactedMessage)

        ---

        \(diagnosticTable(
            kind: kind,
            providerID: providerID,
            origin: origin,
            diagnostics: deviceSnapshot(kind: kind, redactedMessage: redactedMessage)
        ))
        """
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
            timeZone: TimeZone.current.identifier
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
        ## Diagnose
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
        | Provider | \(provider) |

        reisen-fingerprint: `\(diagnostics.fingerprint)`
        <!-- reisen-fingerprint: \(diagnostics.fingerprint) -->
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
