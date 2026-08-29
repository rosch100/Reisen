import Testing
@testable import ReisenAppCore

@Test func githubIssueTitle_reportTitleUsesFirstLineSummary() {
    let title = GitHubIssueTitle.reportTitle(kind: .error, message: "Zeile eins\nZeile zwei")
    #expect(title == "[Fehler] Zeile eins")
}

@Test func githubIssueTitle_reportTitleTrimsAndPrefixesFeedback() {
    let title = GitHubIssueTitle.reportTitle(kind: .feedback, message: "  Hallo Welt  ")
    #expect(title == "[Feedback] Hallo Welt")
}

@Test func githubIssueTitle_storeLoadFailureIsStable() {
    #expect(GitHubIssueTitle.storeLoadFailure.hasPrefix("[Fehler]"))
}

@Test func githubIssueTitle_reportTitleUsesKindPrefix() {
    #expect(GitHubIssueTitle.reportTitle(kind: .error, message: "Timeout") == "[Fehler] Timeout")
    #expect(GitHubIssueTitle.reportTitle(kind: .feedback, message: "Wunsch") == "[Feedback] Wunsch")
}

@Test func githubIssueTitle_reportTitlePrefixesFeature() {
    #expect(
        PasteImportFailedFeatureRequest.titleOverride
            == "[Feature] \(PasteImportFailedFeatureRequest.unrecognizedDocumentMessage)"
    )
}

@Test func githubIssueTitle_overrideReplacesGeneratedTitle() {
    #expect(
        GitHubIssueTitle.reportTitle(kind: .error, message: "ignoriert", override: "Fest") == "Fest"
    )
}

@Test func githubIssueTitle_githubAPITitleRedactsAndLimits() {
    let long = String(repeating: "a", count: 300)
    #expect(GitHubIssueTitle.githubAPITitle(long).count == GitHubIssueTitle.githubAPIMaxLength)
    #expect(!GitHubIssueTitle.githubAPITitle("Token ghp_abcdefghijklmnopqrstuvwxyz0123456789").contains("ghp_"))
}
