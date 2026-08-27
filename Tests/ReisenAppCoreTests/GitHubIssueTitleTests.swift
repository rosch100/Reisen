import Testing
@testable import ReisenAppCore

@Test func githubIssueTitle_syncErrorReportUsesFirstLineSummary() {
    let title = GitHubIssueTitle.syncErrorReport(message: "Zeile eins\nZeile zwei")
    #expect(title == "[Fehler] Zeile eins")
}

@Test func githubIssueTitle_feedbackReportTrimsAndPrefixes() {
    let title = GitHubIssueTitle.feedbackReport(message: "  Hallo Welt  ")
    #expect(title == "[Feedback] Hallo Welt")
}

@Test func githubIssueTitle_storeLoadFailureIsStable() {
    #expect(GitHubIssueTitle.storeLoadFailure.hasPrefix("[Fehler]"))
}
