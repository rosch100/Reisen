import Testing
import Foundation
import ReisenDomain

@Test func providerLoginDisclosure_startsUnaccepted() {
    let suite = "ReisenTests.providerLoginDisclosure"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    #expect(!ProviderLoginDisclosure.isAccepted(defaults: defaults))
    ProviderLoginDisclosure.accept(defaults: defaults)
    #expect(ProviderLoginDisclosure.isAccepted(defaults: defaults))
}

@Test func legalURLs_inAppUsesGitHubPages() {
    #expect(LegalURLs.privacyPolicy.scheme == "https")
    #expect(LegalURLs.privacyPolicy.host == "rosch100.github.io")
    #expect(LegalURLs.privacyPolicy.lastPathComponent == "privacy.html")
    #expect(LegalURLs.support.lastPathComponent == "support.html")
}

@Test func legalURLs_rawFallbackUsesMasterBranch() {
    #expect(LegalURLs.privacyPolicyRaw.host == "raw.githubusercontent.com")
    #expect(
        LegalURLs.privacyPolicyRaw.path
            .contains("/\(GitHubRepository.defaultBranch)/\(GitHubRepository.legalDirectory)/privacy.html")
    )
    #expect(LegalURLs.supportRaw.lastPathComponent == "support.html")
}

@Test func legalURLs_privacyHTMLExistsInRepo() throws {
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let html = repoRoot.appendingPathComponent("docs/legal/privacy.html")
    let support = repoRoot.appendingPathComponent("docs/legal/support.html")
    let index = repoRoot.appendingPathComponent("docs/legal/index.html")
    #expect(FileManager.default.fileExists(atPath: html.path))
    #expect(FileManager.default.fileExists(atPath: support.path))
    #expect(FileManager.default.fileExists(atPath: index.path))
}

@Test func githubRepository_issuesListURL() {
    #expect(GitHubRepository.issuesListURL.absoluteString == "https://github.com/rosch100/Reisen/issues")
    #expect(GitHubRepository.publicPath == "rosch100/Reisen")
    #expect(GitHubRepository.issueURL(number: 42).absoluteString == "https://github.com/rosch100/Reisen/issues/42")
    #expect(GitHubRepository.newIssuePath == "/rosch100/Reisen/issues/new")
    #expect(GitHubRepository.pagesLegalURL(.privacy).lastPathComponent == "privacy.html")
}
