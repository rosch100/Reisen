import Testing
import Foundation
@testable import ReisenAppCore

@Test func githubIssueKind_labelsIncludeSourceInApp() {
    #expect(GitHubIssueKind.error.githubLabels == ["kind/error", "source/in-app"])
    #expect(GitHubIssueKind.feedback.githubLabels == ["kind/feedback", "source/in-app"])
}

@Test func githubIssueKind_usesGermanDisplayNamesAndTemplates() {
    #expect(GitHubIssueKind.error.displayName == "Fehler")
    #expect(GitHubIssueKind.feedback.displayName == "Feedback")
    #expect(GitHubIssueKind.error.issueTemplateFileName == "bug.yml")
    #expect(GitHubIssueKind.feedback.issueTemplateFileName == "feedback.yml")
    #expect(GitHubIssueKind.error.issueFormFieldID == "what")
    #expect(GitHubIssueKind.feedback.issueFormFieldID == "feedback")
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
    let body = GitHubIssueDiagnostic.body(
        kind: .feedback,
        title: "T",
        message: "M",
        providerID: nil,
        origin: .userGitHub(username: "rosch100"),
        appVersion: "1",
        build: "2",
        os: "macOS",
        device: "Mac",
        locale: "de_DE",
        timeZone: "Europe/Berlin",
        fingerprint: "abc"
    )
    #expect(body.contains("| GitHub-Nutzer | @rosch100 |"))
    #expect(body.contains("| Meldeweg | GitHub-Konto |"))
    #expect(body.contains("| Quelle | In-App |"))
    #expect(body.contains("| Art | Feedback |"))
    #expect(body.contains("## Feedback"))
}

@Test func githubIssueDiagnostic_usesGermanErrorSectionForErrors() {
    let body = GitHubIssueDiagnostic.body(
        kind: .error,
        title: "T",
        message: "M",
        providerID: nil,
        origin: .embeddedToken,
        appVersion: "1",
        build: "2",
        os: "macOS",
        device: "Mac",
        locale: "de_DE",
        timeZone: "Europe/Berlin",
        fingerprint: "abc"
    )
    #expect(body.contains("| Art | Fehler |"))
    #expect(body.contains("| Betriebssystem | macOS |"))
    #expect(body.contains("## Fehler"))
}

@Test func githubIssueDiagnostic_includesUnredactedErrorMessage() {
    let body = GitHubIssueDiagnostic.body(
        kind: .error,
        title: "Sync fehlgeschlagen",
        message: "Provider timeout konkret",
        providerID: .opodo,
        origin: .embeddedToken,
        appVersion: "1.2.3",
        build: "45",
        os: "iOS 26.0",
        device: "iPad",
        locale: "de_DE",
        timeZone: "Europe/Berlin",
        fingerprint: "abc"
    )
    #expect(body.contains("Provider timeout konkret"))
    #expect(body.contains("| Provider | Opodo |"))
    #expect(body.contains("1.2.3"))
    #expect(body.contains("iOS 26.0"))
    #expect(body.contains("reisen-fingerprint: `abc`"))
    #expect(!body.contains("Sync-Log"))
    #expect(!body.contains("logTail"))
}

@Test func githubIssueDiagnostic_redactsSecretsInErrorMessage() {
    let body = GitHubIssueDiagnostic.body(
        kind: .error,
        title: "Token ghp_abcdefghijklmnopqrstuvwxyz0123456789",
        message: "Login https://example.com/cb?token=abc&keep=1",
        providerID: nil,
        origin: .embeddedToken,
        appVersion: "1",
        build: "1",
        os: "macOS",
        device: "Mac",
        locale: "de",
        timeZone: "UTC",
        fingerprint: "abc"
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

final class MockGitHubIssues: GitHubIssueSubmitting, @unchecked Sendable {
    var openFingerprints: [String: Int] = [:]
    var createCount = 0
    var searchCount = 0
    var commentCount = 0
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
        commentCount += 1
        return nextComment
    }
}
