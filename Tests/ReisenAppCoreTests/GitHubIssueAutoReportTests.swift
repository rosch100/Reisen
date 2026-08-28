import Testing
import Foundation
import Darwin
import ReisenDomain
import ReisenCrashSignal
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

@Test func githubIssueCrashPending_redactsOnReadForFlush() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-crash-raw-\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: url) }
    try Data("SIGTRAP\n/Users/roschmac/Library/Reisen\n".utf8).write(to: url)
    let message = GitHubIssueCrashCatcher.pendingMessageForReport(at: url, optedIn: true)
    let stored = try #require(message)
    #expect(stored.contains("SIGTRAP"))
    #expect(!stored.contains("roschmac"))
}

@Suite(.serialized)
struct GitHubIssueCrashSignalTests {
    init() {
        reisen_crash_signal_reset_for_tests()
    }

    @Test func writesNameAndHexAddressesToFd() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reisen-sig-fd-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        let fd = open(url.path, O_CREAT | O_RDWR | O_TRUNC, S_IRUSR | S_IWUSR)
        #expect(fd >= 0)
        defer { if fd >= 0 { close(fd) } }
        let frames: [UInt] = [0xABC]
        let ok = frames.withUnsafeBufferPointer { buffer in
            reisen_crash_signal_write_to_fd(fd, SIGTRAP, buffer.baseAddress, Int32(buffer.count))
        }
        #expect(ok)
        fsync(fd)
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("SIGTRAP"))
        #expect(text.lowercased().contains("abc"))
    }

    @Test func optedOutPrepareDoesNotCreateFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reisen-sig-optout-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(reisen_crash_signal_prepare(url.path, false))
        #expect(!reisen_crash_signal_write_current(SIGTRAP))
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func setOptedInAfterPrepareAllowsWrite() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reisen-sig-refresh-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(reisen_crash_signal_prepare(url.path, false))
        reisen_crash_signal_set_opted_in(true)
        #expect(reisen_crash_signal_write_current(SIGTRAP))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("SIGTRAP"))
    }

    @Test func setOptedOutAfterPrepareDoesNotWrite() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reisen-sig-off-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(reisen_crash_signal_prepare(url.path, true))
        reisen_crash_signal_set_opted_in(false)
        #expect(!reisen_crash_signal_write_current(SIGTRAP))
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func existingFileIsNotOverwritten() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reisen-sig-keep-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("NSException: kept\n".utf8).write(to: url)
        #expect(reisen_crash_signal_prepare(url.path, true))
        #expect(!reisen_crash_signal_write_current(SIGABRT))
        let stored = try String(contentsOf: url, encoding: .utf8)
        #expect(stored.contains("NSException: kept"))
        #expect(!stored.contains("SIGABRT"))
    }

    @Test func markWrittenBlocksSubsequentWrite() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reisen-sig-mark-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(reisen_crash_signal_prepare(url.path, true))
        reisen_crash_signal_mark_written()
        #expect(!reisen_crash_signal_write_current(SIGABRT))
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func installIsNoOpWhenDebuggerAttached() {
        #expect(!reisen_crash_signal_install(true))
    }
}
