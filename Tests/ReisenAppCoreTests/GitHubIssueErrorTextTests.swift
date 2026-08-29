import Testing
import Foundation
@testable import ReisenAppCore

@Test func githubIssueErrorText_includesDomainCodeAndUnderlying() {
    let underlying = NSError(
        domain: "NSURLErrorDomain",
        code: -1001,
        userInfo: [NSLocalizedDescriptionKey: "Zeitüberschreitung"]
    )
    let error = NSError(
        domain: "ReisenTest",
        code: 7,
        userInfo: [
            NSLocalizedDescriptionKey: "Sync fehlgeschlagen",
            NSUnderlyingErrorKey: underlying,
        ]
    )
    let dump = GitHubIssueErrorText.dump(error)
    #expect(dump.contains("ReisenTest"))
    #expect(dump.contains("7"))
    #expect(dump.contains("NSURLErrorDomain"))
    #expect(dump.contains("-1001"))
    #expect(dump.contains("Zeitüberschreitung"))
}

@Test func githubIssueErrorText_includesFailureReasonWithoutDumpingSecrets() {
    let error = NSError(
        domain: "ReisenTest",
        code: 1,
        userInfo: [
            NSLocalizedDescriptionKey: "Login fehlgeschlagen",
            NSLocalizedFailureReasonErrorKey: "HTTP 401",
            "Authorization": "Bearer ghp_abcdefghijklmnopqrstuvwxyz0123456789",
        ]
    )
    let dump = GitHubIssueErrorText.dump(error)
    #expect(dump.contains("HTTP 401"))
    #expect(!dump.contains("ghp_abcdefghijklmnopqrstuvwxyz0123456789"))
}
