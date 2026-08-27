import Testing
@testable import ReisenAppCore

@Test func githubIssueReportOrigin_fromEmptyUsernameUsesToken() {
    #expect(GitHubIssueReportOrigin.from(githubUsername: nil) == .embeddedToken)
    #expect(GitHubIssueReportOrigin.from(githubUsername: "   ") == .embeddedToken)
}

@Test func githubIssueReportOrigin_fromUsernameNormalizesAtSign() {
    #expect(GitHubIssueReportOrigin.from(githubUsername: " @rosch100 ") == .userGitHub(username: "rosch100"))
}

@Test func githubIssueTitle_feedbackUsesFirstLineLikeErrors() {
    let title = GitHubIssueTitle.feedbackReport(message: "Zeile eins\nZeile zwei")
    #expect(title == "[Feedback] Zeile eins")
}

@Test func githubIssueTitle_reportTitleUsesKindPrefix() {
    #expect(GitHubIssueTitle.reportTitle(kind: .error, message: "Timeout") == "[Fehler] Timeout")
    #expect(GitHubIssueTitle.reportTitle(kind: .feedback, message: "Wunsch") == "[Feedback] Wunsch")
}
