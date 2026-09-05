import Foundation
import Testing
import ReisenDomain
import ReisenDiagnostics
@testable import ReisenAppCore

@Test func githubIssueCrashReport_titleUsesSignalName() {
    let title = GitHubIssueCrashReport.reportTitle(
        from: "SIGTRAP\ntime_unix=1\n0x1000 Reisen +0xabc\n"
    )
    #expect(title == "[Fehler] SIGTRAP")
}

@Test func githubIssueCrashReport_titleIgnoresSIGPrefixOnExceptionName() {
    let title = GitHubIssueCrashReport.reportTitle(
        from: "SIGPIPEException: broken pipe\n0  Reisen  ..."
    )
    #expect(title == GitHubIssueTitle.uncaughtException)
}

@Test func githubIssueCrashReport_titleKeepsUncaughtExceptionForNSException() {
    let title = GitHubIssueCrashReport.reportTitle(
        from: "NSRangeException: index out of range\n0  Reisen  ..."
    )
    #expect(title == GitHubIssueTitle.uncaughtException)
}

@Test func githubIssueCrashReport_extractsProviderFromPendingLine() {
    let provider = GitHubIssueCrashReport.providerID(
        from: "SIGTRAP\nprovider=booking\nbreadcrumbs:\n"
    )
    #expect(provider == .booking)
}

@Test func githubIssueCrashReport_fingerprintUsesImageOffsetsNotASLR() {
    let a = GitHubIssueCrashReport.fingerprintMaterial(
        from: "SIGTRAP\n0x100cae4f4 Reisen +0xabc\n0x190238144 libswiftCore.dylib +0x10\n"
    )
    let b = GitHubIssueCrashReport.fingerprintMaterial(
        from: "SIGTRAP\n0x200cae4f4 Reisen +0xabc\n0x290238144 libswiftCore.dylib +0x10\n"
    )
    #expect(a == b)
    #expect(a.contains("Reisen +0xabc"))
    #expect(!a.contains("100cae4f4"))
    #expect(
        GitHubIssueFingerprint.hex(kind: .error, message: a)
            == GitHubIssueFingerprint.hex(kind: .error, message: b)
    )
}

@Test func githubIssueCrashReport_skipsSucceededWebViewLifecycleBreadcrumbs() {
    let noise = DiagnosticEvent(
        context: DiagnosticContext(runID: UUID(), providerID: .booking, operation: "startup_probe"),
        component: "ProviderSessionView",
        phase: "lifecycle",
        event: "webview_created",
        result: .succeeded
    )
    let timeout = DiagnosticEvent(
        context: DiagnosticContext(runID: UUID(), providerID: .booking, operation: "startup_probe"),
        component: "ProviderSyncContainer",
        phase: "session_probe",
        event: "timeout",
        result: .timedOut,
        reason: "startup_probe_deadline"
    )
    #expect(!GitHubIssueCrashReport.shouldNote(noise))
    #expect(GitHubIssueCrashReport.shouldNote(timeout))
}

@Test func githubIssueCrashReport_formatsBreadcrumbWithoutURL() {
    let line = GitHubIssueCrashReport.breadcrumbLine(
        from: DiagnosticEvent(
            context: DiagnosticContext(runID: UUID(), providerID: .booking, operation: "startup_probe"),
            component: "ProviderSyncContainer",
            phase: "session_probe",
            event: "timeout",
            result: .timedOut,
            url: "https://secure.booking.com/login?token=secret",
            reason: "startup_probe_deadline"
        )
    )
    #expect(line.contains("provider=booking"))
    #expect(line.contains("component=ProviderSyncContainer"))
    #expect(line.contains("event=timeout"))
    #expect(line.contains("result=timedOut"))
    #expect(line.contains("reason=startup_probe_deadline"))
    #expect(!line.contains("booking.com"))
    #expect(!line.contains("token"))
}

@Test func githubIssueDiagnostic_crashReportOmitsZlibToStayInBodyLimit() {
    let attachment = DiagnosticLogAttachment.makeAttached(
        redactedTail: String(repeating: "x", count: 400) + "\n",
        fileByteCount: 200_000,
        truncated: true
    )
    let body = GitHubIssueDiagnostic.body(
        kind: .error,
        title: "[Fehler] SIGTRAP",
        message: "SIGTRAP\n0x1abc Reisen +0xabc\nimages:\nReisen uuid=AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE\n",
        providerID: .booking,
        origin: .embeddedToken(attributedUsername: nil),
        diagnostics: GitHubIssueDiagnostic.DeviceDiagnostics(
            fingerprint: "abc",
            appVersion: "1",
            build: "2",
            os: "macOS",
            device: "Mac",
            locale: "de_DE",
            timeZone: "Europe/Berlin",
            environment: RuntimeEnvironmentSnapshot(
                architecture: "arm64",
                physicalMemoryBytes: 1,
                processFootprintBytes: nil,
                availableMemoryBytes: nil,
                volumeAvailableBytes: nil,
                thermalState: "nominal",
                lowPowerMode: false,
                processorCount: 1,
                activeProcessorCount: 1,
                systemUptimeSeconds: 1,
                cloudKitEnabled: false
            ),
            logAttachment: attachment
        ),
        includeCompressedLog: false,
        environmentCaptureLabel: GitHubIssueCrashReport.postCrashRelaunchLabel
    )
    #expect(body.count <= GitHubRepository.issueBodyMaxLength)
    #expect(!body.contains("zlib+Base64"))
    #expect(body.contains("## Sync-Log"))
}

@Test func githubIssueDiagnostic_includesEnvironmentCaptureLabel() {
    let body = GitHubIssueDiagnostic.body(
        kind: .error,
        title: "T",
        message: "SIGTRAP",
        providerID: .booking,
        origin: .embeddedToken(attributedUsername: nil),
        diagnostics: GitHubIssueDiagnostic.DeviceDiagnostics(
            fingerprint: "abc",
            appVersion: "1",
            build: "2",
            os: "macOS",
            device: "Mac",
            locale: "de_DE",
            timeZone: "Europe/Berlin",
            environment: RuntimeEnvironmentSnapshot(
                architecture: "arm64",
                physicalMemoryBytes: 1,
                processFootprintBytes: nil,
                availableMemoryBytes: nil,
                volumeAvailableBytes: nil,
                thermalState: "nominal",
                lowPowerMode: false,
                processorCount: 1,
                activeProcessorCount: 1,
                systemUptimeSeconds: 1,
                cloudKitEnabled: false
            ),
            logAttachment: .missing
        ),
        environmentCaptureLabel: GitHubIssueCrashReport.postCrashRelaunchLabel
    )
    #expect(body.contains("| Diagnosezeitpunkt | \(GitHubIssueCrashReport.postCrashRelaunchLabel) |"))
    #expect(body.contains("| Provider | Booking.com |"))
}
