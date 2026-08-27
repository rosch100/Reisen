import Testing
import Foundation
import ReisenDomain

@Test func legalURLs_germanLocaleUsesGermanPages() {
    let locale = Locale(identifier: "de_DE")
    #expect(GitHubRepository.legalPage(for: .privacy, locale: locale) == .privacyDE)
    #expect(GitHubRepository.legalPage(for: .support, locale: locale) == .supportDE)
    #expect(GitHubRepository.pagesLegalURL(for: .privacy, locale: locale).lastPathComponent == "privacy.html")
}

@Test func legalURLs_englishLocaleUsesEnglishPages() {
    let locale = Locale(identifier: "en_US")
    #expect(GitHubRepository.legalPage(for: .privacy, locale: locale) == .privacyEN)
    #expect(GitHubRepository.legalPage(for: .support, locale: locale) == .supportEN)
    #expect(GitHubRepository.pagesLegalURL(for: .support, locale: locale).path.hasSuffix("/en/support.html"))
}

@Test func legalURLs_explicitGermanAndEnglishURLs() {
    #expect(LegalURLs.privacyPolicyGerman.lastPathComponent == "privacy.html")
    #expect(LegalURLs.privacyPolicyEnglish.path.hasSuffix("/en/privacy.html"))
    #expect(LegalURLs.supportGerman.lastPathComponent == "support.html")
    #expect(LegalURLs.supportEnglish.path.hasSuffix("/en/support.html"))
}

@Test func legalURLs_rawFallbackUsesMasterBranch() {
    let locale = Locale(identifier: "de_DE")
    #expect(LegalURLs.privacyPolicyRaw.host == "raw.githubusercontent.com")
    #expect(
        GitHubRepository.rawLegalURL(for: .privacy, locale: locale).path
            .contains("/\(GitHubRepository.defaultBranch)/\(GitHubRepository.legalDirectory)/privacy.html")
    )
}

/// Verifies that every legal page path referenced in code exists under `docs/legal/`.
@Test func legalURLs_allHTMLFilesExistInRepo() throws {
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    for page in [GitHubRepository.LegalPage.privacyDE, .privacyEN, .supportDE, .supportEN] {
        let file = repoRoot.appendingPathComponent("docs/legal/\(page.rawValue)")
        #expect(FileManager.default.fileExists(atPath: file.path), "Missing \(page.rawValue)")
    }
    for legacy in ["privacy.en.html", "support.en.html"] {
        let file = repoRoot.appendingPathComponent("docs/legal/\(legacy)")
        #expect(FileManager.default.fileExists(atPath: file.path), "Missing redirect \(legacy)")
    }
    for page in ["impressum.html", "404.html", "assets/site.css", "assets/app-icon.png"] {
        let file = repoRoot.appendingPathComponent("docs/legal/\(page)")
        #expect(FileManager.default.fileExists(atPath: file.path), "Missing \(page)")
    }
    #expect(FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("docs/legal/en/index.html").path))
    #expect(FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("docs/legal/en/impressum.html").path))
    #expect(FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("docs/legal/index.html").path))
}

@Test func githubRepository_issuesListURL() {
    #expect(GitHubRepository.issuesListURL.absoluteString == "https://github.com/rosch100/Reisen/issues")
    #expect(GitHubRepository.publicPath == "rosch100/Reisen")
    #expect(GitHubRepository.issueURL(number: 42).absoluteString == "https://github.com/rosch100/Reisen/issues/42")
    #expect(GitHubRepository.newIssuePath == "/rosch100/Reisen/issues/new")
}
