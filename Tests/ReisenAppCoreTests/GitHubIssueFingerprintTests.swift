import Testing
@testable import ReisenAppCore

@Test func githubIssueFingerprint_isStableWithoutTimestamp() {
    let a = GitHubIssueFingerprint.hex(
        kind: .error,
        message: "Timeout [2026-08-26T20:00:00Z] beim Sync"
    )
    let b = GitHubIssueFingerprint.hex(
        kind: .error,
        message: "Timeout [2026-08-26T21:11:11Z] beim Sync"
    )
    #expect(a == b)
    #expect(a.count == 64)
}

@Test func githubIssueFingerprint_differsByKind() {
    let error = GitHubIssueFingerprint.hex(kind: .error, message: "Hallo")
    let feedback = GitHubIssueFingerprint.hex(kind: .feedback, message: "Hallo")
    #expect(error != feedback)
}
