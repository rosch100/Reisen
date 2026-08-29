import Testing
@testable import ReisenAppCore

@Test func githubIssueMarkdown_truncatedNeverExceedsBudget() {
    let text = String(repeating: "x", count: 200)
    for budget in [0, 1, 8, 20, 80, 200, 400] {
        let clipped = GitHubIssueMarkdown.truncated(text, maxCharacters: budget)
        #expect(clipped.count <= budget)
    }
}

@Test func githubIssueMarkdown_fenceFittingNeverExceedsBudget() {
    let text = String(repeating: "x", count: 200)
    let withTicks = String(repeating: "`", count: 12) + text
    for budget in [0, 1, 7, 8, 20, 80, 200] {
        #expect(GitHubIssueMarkdown.fenceFitting(text, maxCharacters: budget).count <= budget)
        #expect(GitHubIssueMarkdown.fenceFitting(withTicks, maxCharacters: budget).count <= budget)
    }
}
