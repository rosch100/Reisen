import Testing
import ReisenAppCore

@Test func githubIssueSubmissionMode_usesTokenWhenEmbedded() {
    #expect(GitHubIssueSubmissionMode.resolve(tokenEmbedded: true) == .embeddedToken)
}

@Test func githubIssueSubmissionMode_opensGitHubWhenTokenMissing() {
    #expect(GitHubIssueSubmissionMode.resolve(tokenEmbedded: false) == .openInGitHub)
}
