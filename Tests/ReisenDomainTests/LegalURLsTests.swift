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
    #expect(GitHubRepository.pagesLegalURL(for: .support, locale: locale).path.hasSuffix("/en/support.html"))
    #expect(GitHubRepository.rawLegalURL(for: .support, locale: locale).path.hasSuffix("/en/support.html"))
}

@Test func legalURLs_explicitGermanAndEnglishURLs() {
    #expect(LegalURLs.privacyPolicyGerman.lastPathComponent == "privacy.html")
    #expect(
        LegalURLs.privacyPolicyEnglish.absoluteString
            == "https://rosch100.github.io/Reisen/en/privacy.html"
    )
    #expect(LegalURLs.supportGerman.lastPathComponent == "support.html")
    #expect(LegalURLs.supportEnglish.path.hasSuffix("/en/support.html"))
    #expect(LegalURLs.impressumGerman.lastPathComponent == "impressum.html")
    #expect(LegalURLs.impressumEnglish.path.hasSuffix("/en/impressum.html"))
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
        #expect(page.pagesPath == page.rawValue)
        let content = repoRoot.appendingPathComponent("docs/legal/\(page.rawValue)")
        #expect(FileManager.default.fileExists(atPath: content.path), "Missing \(page.rawValue)")
    }
    for stub in ["privacy.en.html", "support.en.html", "impressum.en.html"] {
        let file = repoRoot.appendingPathComponent("docs/legal/\(stub)")
        #expect(FileManager.default.fileExists(atPath: file.path), "Missing legacy stub \(stub)")
        let html = try String(contentsOf: file, encoding: .utf8)
        #expect(html.localizedCaseInsensitiveContains("http-equiv=\"refresh\""), "Stub \(stub) must redirect")
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
    let siteRoot = GitHubRepository.pagesSiteRootURL.absoluteString
    #expect(!notFoundHTML.contains("<base"))
    #expect(notFoundHTML.contains("href=\"#main\""))
    #expect(notFoundHTML.contains("\(siteRoot)assets/site.css"))
    #expect(notFoundHTML.contains("\(siteRoot)assets/app-icon.png"))
    #expect(notFoundHTML.contains("href=\"\(siteRoot)\""))
    #expect(notFoundHTML.contains("href=\"\(siteRoot)en/\""))
    #expect(notFoundHTML.contains("href=\"\(siteRoot)privacy.html\""))
    #expect(notFoundHTML.contains("href=\"\(siteRoot)support.html\""))
    #expect(notFoundHTML.contains("href=\"\(siteRoot)impressum.html\""))
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
    #expect(issueQueryValue(url, name: "title")?.hasPrefix(GitHubRepository.legalIssueTitlePrefix) == true)
    #expect(url.query?.contains("Impressum") == true)
    #expect(issueQueryValue(url, name: "template") == GitHubRepository.legalIssueTemplateFileName)
    #expect(issueQueryValue(url, name: "body") == nil)
    let notice = try #require(issueQueryValue(url, name: GitHubRepository.legalIssueFormFieldID))
    #expect(!notice.localizedCaseInsensitiveContains("mitteilen"))
    #expect(!notice.localizedCaseInsensitiveContains("please provide"))
    #expect(notice.localizedCaseInsensitiveContains("privaten Kontaktweg"))
    #expect(notice == GitHubRepository.publicIssueNoPersonalDataBody)
}

@Test func githubRepository_privacyRequestIssueURLAvoidsPIIInTemplate() throws {
    let url = GitHubRepository.privacyRequestIssueURL
    #expect(url.path.contains("/issues/new"))
    #expect(issueQueryValue(url, name: "title")?.hasPrefix(GitHubRepository.legalIssueTitlePrefix) == true)
    #expect(url.query?.contains("Datenschutz") == true)
    #expect(url.query?.contains("Buchung") != true)
    #expect(issueQueryValue(url, name: "template") == GitHubRepository.legalIssueTemplateFileName)
    #expect(issueQueryValue(url, name: "body") == nil)
    let notice = try #require(issueQueryValue(url, name: GitHubRepository.legalIssueFormFieldID))
    #expect(!notice.localizedCaseInsensitiveContains("Buchung"))
    #expect(notice == GitHubRepository.publicIssueNoPersonalDataBody)
}

@Test func githubRepository_legalIssueTemplateMatchesSwiftSSOT() throws {
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let legalYAML = try String(
        contentsOf: repoRoot.appendingPathComponent(
            ".github/ISSUE_TEMPLATE/\(GitHubRepository.legalIssueTemplateFileName)"
        ),
        encoding: .utf8
    )
    #expect(legalYAML.contains("title: \"\(GitHubRepository.legalIssueTitlePrefix) \""))
    #expect(legalYAML.contains("id: \(GitHubRepository.legalIssueFormFieldID)"))
    #expect(legalYAML.contains("value: |-"))
    let notice = try #require(yamlLiteralBlock(after: "value: |-", in: legalYAML))
    #expect(notice == GitHubRepository.publicIssueNoPersonalDataBody)
    #expect(!legalYAML.contains("source/in-app"))

    for relative in [GitHubRepository.contactIssuePage, GitHubRepository.privacyRequestPage] {
        let html = try String(
            contentsOf: repoRoot.appendingPathComponent("docs/legal/\(relative)"),
            encoding: .utf8
        )
        #expect(!html.contains("body="), "\(relative) must not use query body after blank_issues_enabled: false")
        if relative == GitHubRepository.contactIssuePage {
            #expect(html.contains(GitHubRepository.htmlEncodedURL(GitHubRepository.contactIssueURL)))
        } else {
            #expect(html.contains(GitHubRepository.htmlEncodedURL(GitHubRepository.privacyRequestIssueURL)))
        }
    }
}

/// Dedentiertes Literal nach `marker` (YAML `|` / `|-`), bis zur nächsten nicht eingerückten Zeile.
private func yamlLiteralBlock(after marker: String, in yaml: String) -> String? {
    guard let markerRange = yaml.range(of: marker) else { return nil }
    let rest = yaml[markerRange.upperBound...]
    var lines: [String] = []
    var started = false
    for line in rest.split(separator: "\n", omittingEmptySubsequences: false) {
        let text = String(line)
        if text.hasPrefix("        ") {
            started = true
            lines.append(String(text.dropFirst(8)))
        } else if text.isEmpty {
            if started { lines.append("") }
        } else if !started {
            continue
        } else {
            break
        }
    }
    while lines.last == "" { lines.removeLast() }
    return lines.isEmpty ? nil : lines.joined(separator: "\n")
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
    #expect(GitHubRepository.feedbackEmail == "reisenapp100@gmail.com")
    #expect(GitHubRepository.feedbackMailtoURL.absoluteString == "mailto:reisenapp100@gmail.com")
    #expect(GitHubRepository.issueURL(number: 42).absoluteString == "https://github.com/rosch100/Reisen/issues/42")
    #expect(GitHubRepository.newIssueFormURL.absoluteString == "https://github.com/rosch100/Reisen/issues/new")
    #expect(GitHubRepository.newIssueFormURL.path == "/rosch100/Reisen/issues/new")
    #expect(GitHubRepository.apiIssuesURL.absoluteString == "https://api.github.com/repos/rosch100/Reisen/issues")
}

@Test func githubRepository_securityAdvisoryURLsMatchPolicyAndTemplates() throws {
    let advisory = GitHubRepository.securityAdvisoryNewURL.absoluteString
    #expect(advisory == "https://github.com/rosch100/Reisen/security/advisories/new")
    #expect(
        GitHubRepository.securityAdvisoriesURL.absoluteString
            == "https://github.com/rosch100/Reisen/security/advisories"
    )

    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let security = try String(contentsOf: repoRoot.appendingPathComponent("SECURITY.md"), encoding: .utf8)
    #expect(security.contains(advisory))
    #expect(security.contains(GitHubRepository.securityAdvisoriesURL.absoluteString))

    let codeOfConduct = try String(
        contentsOf: repoRoot.appendingPathComponent("CODE_OF_CONDUCT.md"),
        encoding: .utf8
    )
    #expect(codeOfConduct.contains(advisory))

    let config = try String(
        contentsOf: repoRoot.appendingPathComponent(".github/ISSUE_TEMPLATE/config.yml"),
        encoding: .utf8
    )
    #expect(config.contains(advisory))
    #expect(config.contains(GitHubRepository.pagesLegalURL(.supportDE).absoluteString))
    #expect(config.contains("mailto:\(GitHubRepository.feedbackEmail)"))

    for name in ["bug.yml", "feedback.yml", "feature.yml", "legal.yml"] {
        let yaml = try String(
            contentsOf: repoRoot.appendingPathComponent(".github/ISSUE_TEMPLATE/\(name)"),
            encoding: .utf8
        )
        #expect(yaml.contains(advisory), "\(name) must link private Security Advisory")
        #expect(
            yaml.contains("Uploads") && yaml.contains(GitHubRepository.feedbackEmail),
            "\(name) must warn that form uploads are public and point to feedback email"
        )
    }
}

@Test func githubRepository_searchOpenIssuesURL() {
    let url = GitHubRepository.searchOpenIssuesURL(fingerprint: "abc123")
    #expect(url?.host == "api.github.com")
    #expect(url?.path == "/search/issues")
    #expect(url?.query?.contains("repo:rosch100/Reisen") == true)
    #expect(url?.query?.contains("abc123") == true)
    #expect(url?.query?.contains("state:open") == true)
    #expect("abc123".count <= GitHubRepository.issueSearchKeywordMaxLength)
}

@Test func githubRepository_restContractMatchesGitHubDocs() {
    #expect(GitHubRepository.restAPIVersion == "2022-11-28")
    #expect(GitHubRepository.restUserAgent == "Reisen")
    #expect(GitHubRepository.issueTitleMaxLength == 256)
    #expect(GitHubRepository.issueBodyMaxLength == 65_536)
    #expect(GitHubRepository.issueMarkdownH2Prefix == "## ")
    #expect(GitHubRepository.issueBodyTruncationNotice.contains(GitHubRepository.feedbackEmail))
    #expect(GitHubRepository.issueAttachmentPolicyCell.contains(GitHubRepository.feedbackEmail))
    #expect(GitHubRepository.issueSearchKeywordMaxLength == 256)
    #expect(GitHubRepository.apiIssuesURL.path == "/repos/rosch100/Reisen/issues")
}

@Test func githubIssueSecretRedactorRules_loadFromDomainBundle() {
    #expect(GitHubIssueSecretRedactorRules.markdownCodeFenceMinLength == 3)
    #expect(GitHubIssueSecretRedactorRules.rules.count >= 20)
    #expect(GitHubIssueSecretRedactorRules.rules.allSatisfy { !$0.pattern.isEmpty && !$0.template.isEmpty })
}
