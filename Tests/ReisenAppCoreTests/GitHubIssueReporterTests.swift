import Testing
import Foundation
import ReisenDomain
@testable import ReisenAppCore

@Test func githubIssueKind_issueTemplatesDeclareKindNotInAppSource() throws {
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    for kind in [GitHubIssueKind.error, .feedback, .feature] {
        let template = repoRoot.appendingPathComponent(
            ".github/ISSUE_TEMPLATE/\(kind.issueForm.templateFileName)"
        )
        let yaml = try String(contentsOf: template, encoding: .utf8)
        #expect(
            yaml.contains("\"kind/\(kind.rawValue)\""),
            "\(kind.issueForm.templateFileName) missing kind/\(kind.rawValue)"
        )
        #expect(
            yaml.contains("id: \(kind.issueForm.fieldID)"),
            "\(kind.issueForm.templateFileName) missing id: \(kind.issueForm.fieldID)"
        )
        #expect(
            yaml.contains("id: privacy_ack"),
            "\(kind.issueForm.templateFileName) missing privacy_ack checkbox"
        )
        #expect(
            !yaml.contains("source/in-app"),
            "\(kind.issueForm.templateFileName) must not apply source/in-app to web form submissions"
        )
        #expect(
            !yaml.contains("source/web"),
            "\(kind.issueForm.templateFileName) must not set source/web (Safari URL adds source/in-app)"
        )
        #expect(kind.githubLabels.contains("source/in-app"))
    }
    #expect(
        !(try String(
            contentsOf: repoRoot.appendingPathComponent(".github/ISSUE_TEMPLATE/feature.yml"),
            encoding: .utf8
        )).contains("Template: copy to Reisen")
    )

    let configYAML = try String(
        contentsOf: repoRoot.appendingPathComponent(".github/ISSUE_TEMPLATE/config.yml"),
        encoding: .utf8
    )
    #expect(configYAML.contains("blank_issues_enabled: false"))
    #expect(configYAML.contains("contact_links:"))
    #expect(configYAML.contains("security/advisories/new"))
    #expect(configYAML.contains(GitHubRepository.feedbackEmail))

    let legalYAML = try String(
        contentsOf: repoRoot.appendingPathComponent(
            ".github/ISSUE_TEMPLATE/\(GitHubRepository.legalIssueTemplateFileName)"
        ),
        encoding: .utf8
    )
    #expect(legalYAML.contains("\"kind/feedback\""))
    #expect(legalYAML.contains("id: \(GitHubRepository.legalIssueFormFieldID)"))
    #expect(legalYAML.contains("title: \"\(GitHubRepository.legalIssueTitlePrefix) \""))
    #expect(legalYAML.contains("value: |-"))
    #expect(legalYAML.contains("id: privacy_ack"))
    #expect(!legalYAML.contains("source/in-app"))
    let notice = try #require(yamlLiteralBlock(after: "value: |-", in: legalYAML))
    #expect(notice == GitHubRepository.publicIssueNoPersonalDataBody)
}

/// Dedentiertes Literal nach `marker` (YAML `|` / `|-`), bis zur nächsten nicht eingerückten Zeile.
private func yamlLiteralBlock(after marker: String, in yaml: String) -> String? {
    guard let markerRange = yaml.range(of: marker) else { return nil }
    let rest = yaml[markerRange.upperBound...]
    var lines: [String] = []
    var started = false
    for line in rest.split(separator: "\n", omittingEmptySubsequences: false) {
        let text = String(line)
        if text.hasPrefix("        ") {
            started = true
            lines.append(String(text.dropFirst(8)))
        } else if text.isEmpty {
            if started { lines.append("") }
        } else if !started {
            continue
        } else {
            break
        }
    }
    while lines.last == "" { lines.removeLast() }
    return lines.isEmpty ? nil : lines.joined(separator: "\n")
}

@Test func githubIssueKind_usesGermanDisplayNamesAndTemplates() {
    #expect(GitHubIssueKind.error.displayName == "Fehler")
    #expect(GitHubIssueKind.feedback.displayName == "Feedback")
    #expect(GitHubIssueKind.error.issueForm.templateFileName == "bug.yml")
    #expect(GitHubIssueKind.feedback.issueForm.templateFileName == "feedback.yml")
    #expect(GitHubIssueKind.error.issueForm.fieldID == "what")
    #expect(GitHubIssueKind.feedback.issueForm.fieldID == "feedback")
}

@Test func githubIssueKind_featureUsesFeatureTemplate() {
    #expect(GitHubIssueKind.feature.displayName == "Feature")
    #expect(GitHubIssueKind.feature.issueForm.templateFileName == "feature.yml")
    #expect(GitHubIssueKind.feature.issueForm.fieldID == "want")
    #expect(GitHubIssueKind.feature.githubLabels == ["kind/feature", "source/in-app"])
}

@Test @MainActor func githubIssueReporter_emptyTokenMakesNoHTTP() async {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { throw GitHubIssueTokenError.notEmbedded },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )

    await #expect(throws: GitHubIssueTokenError.notEmbedded) {
        try await reporter.report(
            kind: .error,
            message: "Provider timeout",
            providerID: nil
        )
    }
    #expect(client.createCount == 0)
    #expect(client.searchCount == 0)
}

@Test @MainActor func githubIssueReporter_createsPublicIssueForUnknownFingerprint() async throws {
    let client = MockGitHubIssues()
    client.nextCreated = GitHubCreatedIssue(
        number: 12,
        htmlURL: URL(string: "https://github.com/rosch100/Reisen/issues/12")!
    )
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "test-token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )

    let created = try await reporter.report(
        kind: .error,
        message: "Provider timeout",
        providerID: .check24
    )

    #expect(created.number == 12)
    #expect(created.htmlURL.absoluteString == "https://github.com/rosch100/Reisen/issues/12")
    #expect(client.createCount == 1)
    #expect(client.lastCreate?.labels == ["kind/error", "source/in-app"])
    #expect(client.lastCreate?.title == "[Fehler] Provider timeout")
    #expect(client.lastCreate?.body.contains("Provider timeout") == true)
    #expect(client.lastCreate?.body.contains("| Provider | Check24 |") == true)
    #expect(client.lastCreate?.body.contains("| Meldeweg | App-Token |") == true)
    #expect(client.lastCreate?.body.contains("reisen-fingerprint:") == true)
    #expect(client.lastCreate?.body.contains("| Architektur |") == true)
    #expect(client.lastCreate?.body.contains("## Sync-Log") == true)
}

@Test @MainActor func githubIssueReporter_embeddedTokenWithAttributedUsername() async throws {
    let client = MockGitHubIssues()
    client.nextCreated = GitHubCreatedIssue(
        number: 13,
        htmlURL: URL(string: "https://github.com/rosch100/Reisen/issues/13")!
    )
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "test-token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )

    _ = try await reporter.report(
        kind: .feedback,
        message: "Test-Feedback",
        providerID: nil,
        reporterGitHubUsername: "rosch100"
    )

    #expect(client.lastCreate?.body.contains("| Meldeweg | App-Token |") == true)
    #expect(client.lastCreate?.body.contains("| GitHub-Nutzer | @rosch100 |") == true)
}

@Test @MainActor func githubIssueReporter_commentsOnDuplicateFingerprint() async throws {
    let fingerprint = GitHubIssueFingerprint.hex(kind: .error, message: "gleiche meldung")
    let client = MockGitHubIssues()
    client.openFingerprints[fingerprint] = 4
    client.nextComment = GitHubCreatedIssue(
        number: 4,
        htmlURL: URL(string: "https://github.com/rosch100/Reisen/issues/4")!
    )
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "test-token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )

    let result = try await reporter.report(
        kind: .error,
        message: "gleiche meldung",
        providerID: nil
    )

    #expect(result.number == 4)
    #expect(client.createCount == 0)
    #expect(client.commentCount == 1)
}

@Test @MainActor func githubIssueReporter_repeatCommentOmitsZlibBlob() async throws {
    let fingerprint = GitHubIssueFingerprint.hex(kind: .error, message: "gleiche meldung")
    let client = MockGitHubIssues()
    client.openFingerprints[fingerprint] = 7
    client.nextComment = GitHubCreatedIssue(
        number: 7,
        htmlURL: URL(string: "https://github.com/rosch100/Reisen/issues/7")!
    )
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "tok" },
        persistenceURL: nil
    )
    _ = try await reporter.report(kind: .error, message: "gleiche meldung", providerID: nil)
    let comment = try #require(client.lastCommentBody)
    #expect(!comment.contains("zlib+Base64"))
    #expect(comment.contains("| RAM physisch |"))
}

@Test @MainActor func githubIssueReporter_rateLimitThrowsWithoutSilentDrop() async {
    let client = MockGitHubIssues()
    client.nextCreated = GitHubCreatedIssue(
        number: 1,
        htmlURL: URL(string: "https://github.com/rosch100/Reisen/issues/1")!
    )
    let current = Date(timeIntervalSince1970: 1_700_000_000)
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "test-token" },
        now: { current },
        maxCreatesPerHour: 1,
        persistenceURL: nil
    )

    _ = try? await reporter.report(
        kind: .error,
        message: "meldung-a",
        providerID: nil
    )

    await #expect(throws: GitHubIssueReporterError.rateLimited) {
        try await reporter.report(
            kind: .error,
            message: "meldung-b",
            providerID: nil
        )
    }
    #expect(client.createCount == 1)
}

@Test func githubIssueDiagnostic_includesGitHubUsernameWhenProvided() {
    let body = diagnosticBody(
        kind: .feedback,
        origin: .userGitHub(username: "rosch100")
    )
    #expect(body.contains("| GitHub-Nutzer | @rosch100 |"))
    #expect(body.contains("| Meldeweg | GitHub-Konto |"))
    #expect(body.contains("| Quelle | In-App |"))
    #expect(body.contains("| Art | Feedback |"))
    #expect(body.contains("## Feedback"))
}

@Test func githubIssueDiagnostic_usesGermanErrorSectionForErrors() {
    let body = diagnosticBody()
    #expect(body.contains("| Art | Fehler |"))
    #expect(body.contains("| Betriebssystem | macOS |"))
    #expect(body.contains("## Fehler"))
}

@Test func githubIssueDiagnostic_includesUnredactedErrorMessage() {
    let body = diagnosticBody(
        title: "Sync fehlgeschlagen",
        message: "Provider timeout konkret",
        providerID: .opodo,
        appVersion: "1.2.3",
        build: "45",
        os: "iOS 26.0",
        device: "iPad"
    )
    #expect(body.contains("Provider timeout konkret"))
    #expect(body.contains("| Provider | Opodo |"))
    #expect(body.contains("1.2.3"))
    #expect(body.contains("iOS 26.0"))
    #expect(body.contains("reisen-fingerprint: `abc`"))
    #expect(body.contains("| Architektur | arm64 |"))
    #expect(body.contains("Sync-Log: nicht vorhanden"))
}

@Test func githubIssueDiagnostic_includesRuntimeEnvironmentRows() {
    let body = diagnosticBody()
    #expect(body.contains("| Architektur | arm64 |"))
    #expect(body.contains("| RAM physisch | 16384 MiB |"))
    #expect(body.contains("| Prozess-Fußabdruck | 200 MiB |"))
    #expect(body.contains("| Freier Prozessspeicher | 800 MiB |"))
    #expect(body.contains("| Freier Volume-Platz | 20.0 GiB |"))
    #expect(body.contains("| Thermal | nominal |"))
    #expect(body.contains("| Energiesparmodus | nein |"))
    #expect(body.contains("| Prozessoren | 8/10 |"))
    #expect(body.contains("| System-Uptime | 3600 s |"))
    #expect(body.contains("| iCloud | an |"))
}

@Test func githubIssueDiagnostic_marksMissingOptionalEnvironmentAsUnavailable() {
    let body = diagnosticBody(
        environment: diagnosticTestEnvironment(
            processFootprintBytes: nil,
            availableMemoryBytes: nil,
            volumeAvailableBytes: nil,
            cloudKitEnabled: false,
            thermalState: "nicht verfügbar"
        )
    )
    #expect(body.contains("| Prozess-Fußabdruck | nicht verfügbar |"))
    #expect(body.contains("| Freier Prozessspeicher | nicht verfügbar |"))
    #expect(body.contains("| Freier Volume-Platz | nicht verfügbar |"))
    #expect(body.contains("| iCloud | aus |"))
    #expect(!body.contains("| Prozess-Fußabdruck | 0 MiB |"))
}

@Test func githubIssueDiagnostic_includesRedactedCompressedSyncLog() {
    let tail = "ok line\nsecret gast@domain.de\n"
    let attachment = DiagnosticLogAttachment.makeAttached(
        redactedTail: SecretRedactor.redact(tail),
        fileByteCount: 80,
        truncated: false
    )
    let body = diagnosticBody(logAttachment: attachment, includeCompressedLog: true)
    #expect(body.contains("## Sync-Log"))
    #expect(body.contains("| truncated | nein |"))
    #expect(body.contains("ok line"))
    #expect(!body.contains("gast@domain.de"))
    #expect(body.contains("[redacted]"))
    #expect(body.contains("zlib+Base64"))
}

@Test func githubIssueDiagnostic_compressionFailedKeepsPreview() {
    let body = diagnosticBody(
        logAttachment: .compressionFailed(preview: "last-line"),
        includeCompressedLog: true
    )
    #expect(body.contains("last-line"))
    #expect(body.contains("Kompression fehlgeschlagen"))
    #expect(!body.contains("zlib+Base64"))
}

@Test func githubIssueDiagnostic_urlFormOmitsZlibBlob() {
    let attachment = DiagnosticLogAttachment.makeAttached(
        redactedTail: "only-preview\n",
        fileByteCount: 12,
        truncated: false
    )
    let field = GitHubIssueDiagnostic.collectedFormFieldContent(
        kind: .error,
        message: "Timeout",
        providerID: nil,
        origin: .embeddedToken(attributedUsername: nil),
        diagnostics: GitHubIssueDiagnostic.DeviceDiagnostics(
            fingerprint: "abc",
            appVersion: "1",
            build: "2",
            os: "macOS",
            device: "Mac",
            locale: "de_DE",
            timeZone: "Europe/Berlin",
            environment: diagnosticTestEnvironment(),
            logAttachment: attachment
        )
    )
    #expect(field.contains("| Architektur |"))
    #expect(!field.contains("zlib+Base64"))
    #expect(!field.contains("## Sync-Log"))
}

@Test func githubIssueDiagnostic_payloadIsSeparateFromBannerMessage() {
    struct TimeoutError: LocalizedError {
        var errorDescription: String? { "Provider timeout konkret" }
    }
    let banner = SyncStore.bannerMessage(from: TimeoutError())
    #expect(banner == "Provider timeout konkret")
    #expect(!banner.contains("Sync-Log"))
    #expect(!banner.contains("MiB"))
    let payload = diagnosticBody(
        message: banner,
        logAttachment: DiagnosticLogAttachment.makeAttached(
            redactedTail: "log-line\n",
            fileByteCount: 8,
            truncated: false
        )
    )
    #expect(payload.contains("## Sync-Log"))
    #expect(payload.contains("| RAM physisch |"))
    #expect(banner != payload)
}

@Test func githubIssueDiagnostic_fingerprintIgnoresEnvironmentAndLog() {
    let message = "Provider timeout konkret"
    let fp = GitHubIssueFingerprint.hex(kind: .error, message: message)
    let low = diagnosticBody(
        message: message,
        fingerprint: fp,
        environment: diagnosticTestEnvironment(
            processFootprintBytes: nil,
            volumeAvailableBytes: nil
        ),
        logAttachment: .missing
    )
    let high = diagnosticBody(
        message: message,
        fingerprint: fp,
        environment: diagnosticTestEnvironment(),
        logAttachment: DiagnosticLogAttachment.makeAttached(
            redactedTail: "log-line\n",
            fileByteCount: 8,
            truncated: false
        )
    )
    #expect(low.contains("reisen-fingerprint: `\(fp)`"))
    #expect(high.contains("reisen-fingerprint: `\(fp)`"))
    #expect(low.contains("nicht verfügbar"))
    #expect(high.contains("zlib+Base64"))
}

@Test func githubIssueDiagnostic_redactsEmailInErrorMessage() {
    let body = diagnosticBody(
        title: "Kontakt test@example.com",
        message: "Fehler für gast@domain.de bei Sync",
        locale: "de",
        timeZone: "UTC"
    )
    #expect(!body.contains("test@example.com"))
    #expect(!body.contains("gast@domain.de"))
    #expect(body.contains("[redacted]"))
}

@Test func githubIssueDiagnostic_redactsSecretsInErrorMessage() {
    let body = diagnosticBody(
        title: "Token ghp_abcdefghijklmnopqrstuvwxyz0123456789",
        message: "Login https://example.com/cb?token=abc&keep=1",
        locale: "de",
        timeZone: "UTC"
    )
    #expect(body.contains("keep=1"))
    #expect(!body.contains("ghp_abcdefghijklmnopqrstuvwxyz0123456789"))
    #expect(!body.contains("token=abc"))
    #expect(body.contains("[redacted]"))
}

@Test func githubIssueAPIClientError_httpStatusIncludesRedactedSnippet() {
    let data = Data(#"{"message":"Bad credentials Bearer ghp_abcdefghijklmnopqrstuvwxyz0123456789"}"#.utf8)
    let error = GitHubIssueAPIClientError.httpFailure(status: 401, data: data)
    #expect(error.localizedDescription.contains("401"))
    #expect(!error.localizedDescription.contains("ghp_abcdefghijklmnopqrstuvwxyz0123456789"))
    #expect(error.localizedDescription.contains("[redacted]"))
}

@Test @MainActor func githubIssueReporter_localFingerprintSkipsSearch() async throws {
    let stateURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-issue-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: stateURL) }

    let firstClient = MockGitHubIssues()
    firstClient.nextCreated = GitHubCreatedIssue(
        number: 9,
        htmlURL: URL(string: "https://github.com/rosch100/Reisen/issues/9")!
    )
    let first = GitHubIssueReporter(
        client: firstClient,
        tokenProvider: { "test-token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: stateURL
    )
    _ = try await first.report(
        kind: .error,
        message: "persistente meldung",
        providerID: nil
    )

    let secondClient = MockGitHubIssues()
    secondClient.nextComment = GitHubCreatedIssue(
        number: 9,
        htmlURL: URL(string: "https://github.com/rosch100/Reisen/issues/9")!
    )
    let second = GitHubIssueReporter(
        client: secondClient,
        tokenProvider: { "test-token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: stateURL
    )
    let again = try await second.report(
        kind: .error,
        message: "persistente meldung",
        providerID: nil
    )
    #expect(again.number == 9)
    #expect(secondClient.searchCount == 0)
    #expect(secondClient.createCount == 0)
    #expect(secondClient.commentCount == 1)
}

@Test @MainActor func githubIssueReporter_commentThrottleReturnsExistingWithoutNewComment() async throws {
    let fingerprint = GitHubIssueFingerprint.hex(kind: .error, message: "gleiche meldung")
    let client = MockGitHubIssues()
    client.openFingerprints[fingerprint] = 4
    client.nextComment = GitHubCreatedIssue(
        number: 4,
        htmlURL: URL(string: "https://github.com/rosch100/Reisen/issues/4")!
    )
    let current = Date(timeIntervalSince1970: 1_700_000_000)
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "test-token" },
        now: { current },
        persistenceURL: nil
    )

    let first = try await reporter.report(
        kind: .error,
        message: "gleiche meldung",
        providerID: nil
    )
    #expect(first.didPostUpdate)
    #expect(client.commentCount == 1)

    let second = try await reporter.report(
        kind: .error,
        message: "gleiche meldung",
        providerID: nil
    )
    #expect(second.number == 4)
    #expect(second.didPostUpdate == false)
    #expect(client.commentCount == 1)
    #expect(client.createCount == 0)
}

@Test @MainActor func githubIssueReporter_persistsRateLimitAcrossInstances() async throws {
    let stateURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-issue-rl-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: stateURL) }
    let current = Date(timeIntervalSince1970: 1_700_000_000)

    let firstClient = MockGitHubIssues()
    firstClient.nextCreated = GitHubCreatedIssue(
        number: 1,
        htmlURL: URL(string: "https://github.com/rosch100/Reisen/issues/1")!
    )
    let first = GitHubIssueReporter(
        client: firstClient,
        tokenProvider: { "test-token" },
        now: { current },
        maxCreatesPerHour: 1,
        persistenceURL: stateURL
    )
    _ = try await first.report(
        kind: .error,
        message: "meldung-persist-a",
        providerID: nil
    )

    let secondClient = MockGitHubIssues()
    let second = GitHubIssueReporter(
        client: secondClient,
        tokenProvider: { "test-token" },
        now: { current },
        maxCreatesPerHour: 1,
        persistenceURL: stateURL
    )
    await #expect(throws: GitHubIssueReporterError.rateLimited) {
        try await second.report(
            kind: .error,
            message: "meldung-persist-b",
            providerID: nil
        )
    }
    #expect(secondClient.createCount == 0)
}

@Test @MainActor func githubIssueReporter_corruptPersistenceThrowsWithoutResettingLimit() async throws {
    let stateURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-issue-corrupt-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: stateURL) }
    try Data("{not-json".utf8).write(to: stateURL)

    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "test-token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: stateURL
    )
    await #expect(throws: GitHubIssueReporterError.persistedStateCorrupt) {
        try await reporter.report(
            kind: .error,
            message: "meldung-corrupt",
            providerID: nil
        )
    }
    #expect(client.createCount == 0)
    let leftover = try String(contentsOf: stateURL, encoding: .utf8)
    #expect(leftover.contains("{not-json"))
}

private func diagnosticTestEnvironment(
    processFootprintBytes: UInt64? = 200 * 1024 * 1024,
    availableMemoryBytes: UInt64? = 800 * 1024 * 1024,
    volumeAvailableBytes: Int64? = 20 * 1024 * 1024 * 1024,
    cloudKitEnabled: Bool = true,
    thermalState: String = "nominal"
) -> RuntimeEnvironmentSnapshot {
    RuntimeEnvironmentSnapshot(
        architecture: "arm64",
        physicalMemoryBytes: 16 * 1024 * 1024 * 1024,
        processFootprintBytes: processFootprintBytes,
        availableMemoryBytes: availableMemoryBytes,
        volumeAvailableBytes: volumeAvailableBytes,
        thermalState: thermalState,
        lowPowerMode: false,
        processorCount: 10,
        activeProcessorCount: 8,
        systemUptimeSeconds: 3600,
        cloudKitEnabled: cloudKitEnabled
    )
}

private func diagnosticBody(
    kind: GitHubIssueKind = .error,
    title: String = "T",
    message: String = "M",
    providerID: ProviderID? = nil,
    origin: GitHubIssueReportOrigin = .embeddedToken(attributedUsername: nil),
    appVersion: String = "1",
    build: String = "2",
    os: String = "macOS",
    device: String = "Mac",
    locale: String = "de_DE",
    timeZone: String = "Europe/Berlin",
    fingerprint: String = "abc",
    environment: RuntimeEnvironmentSnapshot = diagnosticTestEnvironment(),
    logAttachment: DiagnosticLogAttachment = .missing,
    includeCompressedLog: Bool = true
) -> String {
    GitHubIssueDiagnostic.body(
        kind: kind,
        title: title,
        message: message,
        providerID: providerID,
        origin: origin,
        diagnostics: GitHubIssueDiagnostic.DeviceDiagnostics(
            fingerprint: fingerprint,
            appVersion: appVersion,
            build: build,
            os: os,
            device: device,
            locale: locale,
            timeZone: timeZone,
            environment: environment,
            logAttachment: logAttachment
        ),
        includeCompressedLog: includeCompressedLog
    )
}

final class MockGitHubIssues: GitHubIssueSubmitting, @unchecked Sendable {
    var openFingerprints: [String: Int] = [:]
    var createCount = 0
    var searchCount = 0
    var commentCount = 0
    var commentError: (any Error)?
    var commentBodies: [String] = []
    var lastCommentBody: String?
    var lastCreate: (title: String, body: String, labels: [String])?
    var nextCreated = GitHubCreatedIssue(
        number: 1,
        htmlURL: URL(string: "https://github.com/rosch100/Reisen/issues/1")!
    )
    var nextComment = GitHubCreatedIssue(
        number: 1,
        htmlURL: URL(string: "https://github.com/rosch100/Reisen/issues/1")!
    )

    func searchOpenFingerprint(_ fingerprint: String) async throws -> Int? {
        searchCount += 1
        return openFingerprints[fingerprint]
    }

    func createIssue(title: String, body: String, labels: [String]) async throws -> GitHubCreatedIssue {
        createCount += 1
        lastCreate = (title, body, labels)
        return nextCreated
    }

    func comment(issueNumber: Int, body: String) async throws -> GitHubCreatedIssue {
        if let commentError {
            throw commentError
        }
        commentCount += 1
        commentBodies.append(body)
        lastCommentBody = body
        return nextComment
    }
}
