import Testing
import ReisenDomain
@testable import ReisenAppCore

@Test func githubIssueReportOrigin_embeddedTokenWithoutAttribution() {
    let origin = GitHubIssueReportOrigin.embeddedToken(attributedUsername: nil)
    #expect(origin.meldewegLabel == "App-Token")
    #expect(origin.githubUserLabel == "—")
}

@Test func githubIssueReportOrigin_embeddedTokenWithAttribution() {
    let origin = GitHubIssueReportOrigin.embeddedToken(
        attributedUsername: GitHubUsername.optionalValid(" @rosch100 ")
    )
    #expect(origin == .embeddedToken(attributedUsername: "rosch100"))
    #expect(origin.meldewegLabel == "App-Token")
    #expect(origin.githubUserLabel == "@rosch100")
}

@Test func githubIssueReportOrigin_userGitHubSubmission() {
    let origin = GitHubIssueReportOrigin.userGitHub(username: "rosch100")
    #expect(origin.meldewegLabel == "GitHub-Konto")
    #expect(origin.githubUserLabel == "@rosch100")
}
