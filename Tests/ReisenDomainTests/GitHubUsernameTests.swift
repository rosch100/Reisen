import Foundation
import Testing
import ReisenDomain

@Test func githubUsername_normalizesLeadingAtSign() {
    #expect(GitHubUsername.normalized("  @rosch100 ") == "rosch100")
}

@Test func githubUsername_acceptsTypicalLogin() {
    #expect(GitHubUsername.isValid("rosch100"))
    #expect(!GitHubUsername.isValid("my-user_1"))
    #expect(GitHubUsername.isValid(String(repeating: "a", count: GitHubUsername.maxLength)))
    #expect(!GitHubUsername.isValid(String(repeating: "a", count: GitHubUsername.maxLength + 1)))
}

@Test func githubUsername_rejectsEmptyAfterNormalization() {
    #expect(GitHubUsername.validationError(for: "   ") == nil)
    #expect(GitHubUsername.validationError(for: "@") == "Ungültiger GitHub-Benutzername.")
}

@Test func githubUsername_rejectsInvalidCharacters() {
    #expect(GitHubUsername.validationError(for: "bad name") == "Ungültiger GitHub-Benutzername.")
}

@Test func githubUsername_optionalValidAcceptsOnlyGitHubLogins() {
    #expect(GitHubUsername.optionalValid(nil) == nil)
    #expect(GitHubUsername.optionalValid("  ") == nil)
    #expect(GitHubUsername.optionalValid("bad name") == nil)
    #expect(GitHubUsername.optionalValid(" @rosch100 ") == "rosch100")
}

@Test func githubUsername_attributionRequiresValidWhenFieldVisible() {
    let invalid = GitHubUsername.attribution(from: "bad name", requireValid: true)
    #expect(invalid.username == nil)
    #expect(invalid.error == "Ungültiger GitHub-Benutzername.")

    let valid = GitHubUsername.attribution(from: " @rosch100 ", requireValid: true)
    #expect(valid.username == "rosch100")
    #expect(valid.error == nil)
}

@Test func githubUsername_attributionIgnoresInvalidWhenFieldHidden() {
    let ignored = GitHubUsername.attribution(from: "bad name", requireValid: false)
    #expect(ignored.username == nil)
    #expect(ignored.error == nil)

    let valid = GitHubUsername.attribution(from: " @rosch100 ", requireValid: false)
    #expect(valid.username == "rosch100")
    #expect(valid.error == nil)
}

@Test func optionalFeedbackGitHubUsername_ignoresInvalidValues() {
    let suite = "ReisenTests.feedbackGitHubUsername.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }

    defaults.set("not a login!", forKey: AppSettingsKeys.feedbackGitHubUsername)
    #expect(AppSettingsKeys.optionalFeedbackGitHubUsername(defaults: defaults) == nil)

    defaults.set("@rosch100", forKey: AppSettingsKeys.feedbackGitHubUsername)
    #expect(AppSettingsKeys.optionalFeedbackGitHubUsername(defaults: defaults) == "rosch100")
}

@Test func feedbackGitHubUsernameKey_isStableAndPrefixed() {
    #expect(AppSettingsKeys.feedbackGitHubUsername == "reisen_feedbackGitHubUsername")
}
