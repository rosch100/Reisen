import Testing
@testable import ReisenAppCore

@Test func githubIssueReportOrigin_embeddedTokenWithoutAttribution() {
    let origin = GitHubIssueReportOrigin.embeddedToken(attributedUsername: nil)
    #expect(origin.meldewegLabel == "App-Token")
    #expect(origin.githubUserLabel == "—")
}

@Test func githubIssueReportOrigin_embeddedTokenWithAttribution() {
    let origin = GitHubIssueReportOrigin.embeddedToken(
        attributedUsername: GitHubIssueReportOrigin.optionalNormalizedUsername(" @rosch100 ")
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

@Test func githubIssueTitle_feedbackUsesFirstLineLikeErrors() {
    let title = GitHubIssueTitle.feedbackReport(message: "Zeile eins\nZeile zwei")
    #expect(title == "[Feedback] Zeile eins")
}

@Test func githubIssueTitle_reportTitleUsesKindPrefix() {
    #expect(GitHubIssueTitle.reportTitle(kind: .error, message: "Timeout") == "[Fehler] Timeout")
    #expect(GitHubIssueTitle.reportTitle(kind: .feedback, message: "Wunsch") == "[Feedback] Wunsch")
}
