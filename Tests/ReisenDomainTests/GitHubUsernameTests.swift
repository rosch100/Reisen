import Testing
import ReisenDomain

@Test func githubUsername_normalizesLeadingAtSign() {
    #expect(GitHubUsername.normalized("  @rosch100 ") == "rosch100")
}

@Test func githubUsername_acceptsTypicalLogin() {
    #expect(GitHubUsername.isValid("rosch100"))
    #expect(!GitHubUsername.isValid("my-user_1"))
}

@Test func githubUsername_rejectsEmptyAfterNormalization() {
    #expect(GitHubUsername.validationError(for: "   ") == nil)
    #expect(GitHubUsername.validationError(for: "@") == "Ungültiger GitHub-Benutzername.")
}

@Test func githubUsername_rejectsInvalidCharacters() {
    #expect(GitHubUsername.validationError(for: "bad name") == "Ungültiger GitHub-Benutzername.")
}

@Test func feedbackGitHubUsernameKey_isStableAndPrefixed() {
    #expect(AppSettingsKeys.feedbackGitHubUsername == "reisen_feedbackGitHubUsername")
}
