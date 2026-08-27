import Testing
import Foundation
import ReisenDomain
@testable import ReisenAppCore

private struct LocalizedMessage: LocalizedError {
    let errorDescription: String?
}

private struct PrivacyDenied: Error, PrivacyAccessDenying {
    var privacySettingPane: PrivacySettingPane? { .calendars }
}

@Test func githubIssueAutoReport_skipsPrivacyDenialAndSessionRecovery() {
    #expect(!GitHubIssueAutoReport.shouldReport(error: PrivacyDenied()))
    #expect(
        !GitHubIssueAutoReport.shouldReport(
            error: LocalizedMessage(
                errorDescription: "Es besteht noch keine Check24 Session. Bitte zunächst anmelden."
            )
        )
    )
    #expect(
        !GitHubIssueAutoReport.shouldReport(
            error: LocalizedMessage(
                errorDescription: "Traveloka-Session ohne Sentinel-Cookie (sen_t) — bitte erneut anmelden."
            )
        )
    )
    #expect(
        GitHubIssueAutoReport.shouldReport(
            error: LocalizedMessage(errorDescription: "Traveloka-Antwort konnte nicht gelesen werden.")
        )
    )
}

@Test func githubIssueAutoReport_skipsExpectedUserStateMessages() {
    #expect(!GitHubIssueAutoReport.shouldReport(message: "Provider check24 ist deaktiviert."))
    #expect(!GitHubIssueAutoReport.shouldReport(message: "Keine angemeldeten Provider zum Synchronisieren."))
    #expect(GitHubIssueAutoReport.shouldReport(message: "Provider timeout konkret"))
}

@Test func githubIssueAutoReport_skipsWhenOptedInWithoutEmbeddedToken() {
    let suite = "ReisenTests.autoReportNoToken"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    defaults.set(true, forKey: AppSettingsKeys.reportErrorsToGitHub)
    #expect(!GitHubIssueAutoReport.isAutomaticReportingEnabled(defaults: defaults))
}

@Test func githubIssueCrashPending_notWrittenWhenOptedOut() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-crash-\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: url) }
    GitHubIssueCrashCatcher.writePending("boom", to: url, optedIn: false)
    #expect(!FileManager.default.fileExists(atPath: url.path))
}

@Test func githubIssueCrashPending_discardedWhenOptedOut() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-crash-\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: url) }
    try Data("boom".utf8).write(to: url)
    let message = GitHubIssueCrashCatcher.pendingMessageForReport(at: url, optedIn: false)
    #expect(message == nil)
    #expect(!FileManager.default.fileExists(atPath: url.path))
}

@Test func githubIssueCrashPending_keepsTechnicalMessageWhenOptedIn() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-crash-\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: url) }
    GitHubIssueCrashCatcher.writePending("boom", to: url, optedIn: true)
    let message = GitHubIssueCrashCatcher.pendingMessageForReport(at: url, optedIn: true)
    #expect(message == "boom")
}

@Test func githubIssueCrashPending_anonymizesPrivateDataBeforeWrite() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-crash-\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: url) }
    GitHubIssueCrashCatcher.writePending(
        "NSException: Sync für test@example.com Vorname: Erika",
        to: url,
        optedIn: true
    )
    let message = GitHubIssueCrashCatcher.pendingMessageForReport(at: url, optedIn: true)
    let stored = try #require(message)
    #expect(stored.contains("NSException:"))
    #expect(!stored.contains("test@example.com"))
    #expect(!stored.contains("Erika"))
    #expect(stored.contains("[redacted]"))
}

@Test func githubIssueCrashPending_anonymizesHomePathsBeforeWrite() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-crash-\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: url) }
    GitHubIssueCrashCatcher.writePending(
        "NSRangeException\n0  Reisen  /Users/roschmac/Library/Reisen.debug.dylib",
        to: url,
        optedIn: true
    )
    let stored = try #require(GitHubIssueCrashCatcher.pendingMessageForReport(at: url, optedIn: true))
    #expect(stored.contains("NSRangeException"))
    #expect(!stored.contains("roschmac"))
    #expect(stored.contains("/Users/[redacted]/"))
}
