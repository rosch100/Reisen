import Testing
import Foundation
import ReisenDomain

@Test func legalURLs_germanLocaleUsesGermanPages() {
    let locale = Locale(identifier: "de_DE")
    #expect(GitHubRepository.legalPage(for: .privacy, locale: locale) == .privacyDE)
    #expect(GitHubRepository.legalPage(for: .support, locale: locale) == .supportDE)
    #expect(GitHubRepository.legalPage(for: .impressum, locale: locale) == .impressumDE)
    #expect(GitHubRepository.pagesLegalURL(for: .privacy, locale: locale).lastPathComponent == "privacy.html")
}

@Test func legalURLs_englishLocaleUsesEnglishPages() {
    let locale = Locale(identifier: "en_US")
    #expect(GitHubRepository.legalPage(for: .privacy, locale: locale) == .privacyEN)
    #expect(GitHubRepository.legalPage(for: .support, locale: locale) == .supportEN)
    #expect(GitHubRepository.legalPage(for: .impressum, locale: locale) == .impressumEN)
    #expect(GitHubRepository.pagesLegalURL(for: .support, locale: locale).path.hasSuffix("/support.en.html"))
    #expect(GitHubRepository.rawLegalURL(for: .support, locale: locale).path.hasSuffix("/en/support.html"))
}

@Test func legalURLs_explicitGermanAndEnglishURLs() {
    #expect(LegalURLs.privacyPolicyGerman.lastPathComponent == "privacy.html")
    #expect(LegalURLs.privacyPolicyEnglish.path.hasSuffix("/privacy.en.html"))
    #expect(LegalURLs.supportGerman.lastPathComponent == "support.html")
    #expect(LegalURLs.supportEnglish.path.hasSuffix("/support.en.html"))
    #expect(LegalURLs.impressumGerman.lastPathComponent == "impressum.html")
    #expect(LegalURLs.impressumEnglish.path.hasSuffix("/impressum.en.html"))
}

@Test func legalURLs_rawFallbackUsesMasterBranch() {
    let locale = Locale(identifier: "de_DE")
    #expect(LegalURLs.privacyPolicyRaw.host == "raw.githubusercontent.com")
    #expect(
        GitHubRepository.rawLegalURL(for: .privacy, locale: locale).path
            .contains("/\(GitHubRepository.defaultBranch)/\(GitHubRepository.legalDirectory)/privacy.html")
    )
    let english = Locale(identifier: "en_US")
    #expect(
        GitHubRepository.rawLegalURL(for: .privacy, locale: english).path.hasSuffix("/en/privacy.html")
    )
}

/// Verifies that every legal page path referenced in code exists under `docs/legal/`.
@Test func legalURLs_allHTMLFilesExistInRepo() throws {
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    for page in GitHubRepository.LegalPage.allCases {
        let content = repoRoot.appendingPathComponent("docs/legal/\(page.rawValue)")
        #expect(FileManager.default.fileExists(atPath: content.path), "Missing \(page.rawValue)")
        let pages = repoRoot.appendingPathComponent("docs/legal/\(page.pagesPath)")
        #expect(FileManager.default.fileExists(atPath: pages.path), "Missing \(page.pagesPath)")
    }
    for redirect in [GitHubRepository.privacyRequestPage, GitHubRepository.contactIssuePage] {
        let file = repoRoot.appendingPathComponent("docs/legal/\(redirect)")
        #expect(FileManager.default.fileExists(atPath: file.path), "Missing \(redirect)")
    }
    for page in ["impressum.html", "404.html", "assets/site.css", "assets/app-icon.png"] {
        let file = repoRoot.appendingPathComponent("docs/legal/\(page)")
        #expect(FileManager.default.fileExists(atPath: file.path), "Missing \(page)")
    }
    let notFoundHTML = try String(
        contentsOf: repoRoot.appendingPathComponent("docs/legal/404.html"),
        encoding: .utf8
    )
    #expect(notFoundHTML.contains(GitHubRepository.pagesSiteRootURL.absoluteString))
    #expect(FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("docs/legal/en/index.html").path))
    #expect(FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("docs/legal/en/impressum.html").path))
    #expect(FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("docs/legal/index.html").path))
}

@Test func githubRepository_pagesSiteRootURL() {
    #expect(GitHubRepository.pagesSiteRootURL.absoluteString == "https://rosch100.github.io/Reisen/")
}

@Test func githubRepository_contactIssueURL() throws {
    let url = GitHubRepository.contactIssueURL
    #expect(url.host == "github.com")
    #expect(url.path.contains("/issues/new"))
    #expect(url.query?.contains("Kontakt") == true)
    let body = try #require(issueQueryValue(url, name: "body"))
    #expect(!body.localizedCaseInsensitiveContains("mitteilen"))
    #expect(!body.localizedCaseInsensitiveContains("please provide"))
    #expect(body.localizedCaseInsensitiveContains("privaten Kontaktweg"))
}

@Test func githubRepository_privacyRequestIssueURLAvoidsPIIInTemplate() throws {
    let url = GitHubRepository.privacyRequestIssueURL
    #expect(url.path.contains("/issues/new"))
    #expect(url.query?.contains("Datenschutz") == true)
    #expect(url.query?.contains("Buchung") != true)
    let body = try #require(issueQueryValue(url, name: "body"))
    #expect(!body.localizedCaseInsensitiveContains("Buchung"))
}

private func issueQueryValue(_ url: URL, name: String) -> String? {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?
        .queryItems?
        .first(where: { $0.name == name })?
        .value
}

@Test func githubRepository_issuesListURL() {
    #expect(GitHubRepository.issuesListURL.absoluteString == "https://github.com/rosch100/Reisen/issues")
    #expect(GitHubRepository.publicPath == "rosch100/Reisen")
    #expect(GitHubRepository.issueURL(number: 42).absoluteString == "https://github.com/rosch100/Reisen/issues/42")
    #expect(GitHubRepository.newIssueFormURL.absoluteString == "https://github.com/rosch100/Reisen/issues/new")
    #expect(GitHubRepository.newIssueFormURL.path == "/rosch100/Reisen/issues/new")
    #expect(GitHubRepository.apiIssuesURL.absoluteString == "https://api.github.com/repos/rosch100/Reisen/issues")
}

@Test func githubRepository_searchOpenIssuesURL() {
    let url = GitHubRepository.searchOpenIssuesURL(fingerprint: "abc123")
    #expect(url?.host == "api.github.com")
    #expect(url?.path == "/search/issues")
    #expect(url?.query?.contains("repo:rosch100/Reisen") == true)
    #expect(url?.query?.contains("abc123") == true)
    #expect(url?.query?.contains("state:open") == true)
}
