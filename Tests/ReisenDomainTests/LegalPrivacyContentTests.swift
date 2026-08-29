import Foundation
import Testing
import ReisenDomain

private func legalFile(_ relative: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("docs/legal/\(relative)")
    return try String(contentsOf: url, encoding: .utf8)
}

private func htmlContainsURL(_ html: String, _ url: URL) -> Bool {
    html.contains(url.absoluteString) || html.contains(GitHubRepository.htmlEncodedURL(url))
}

@Test func privacyPolicyGerman_coversAppProcessingAndArt13() throws {
    let html = try legalFile("privacy.html")
    for needle in [
        "Art. 6 Abs. 1",
        "Aufsichtsbehörde",
        "Geburtsdatum",
        "MapKit",
        "Zeitzone",
        "installierte",
        "Einwilligung",
        "Speicherdauer",
        "Minderjährige",
        "automatisch",
        "Stack",
        "IP-Adresse",
        "Subprozessoren",
        "Cookie-Banner",
        "Standardvertragsklauseln",
        "Paste-Import",
        "Private Cloud Compute",
        "ephemer",
        "Feature-Request",
        "Bestätigung",
        "öffentlich",
    ] {
        #expect(html.localizedCaseInsensitiveContains(needle), "privacy.html missing \(needle)")
    }
}

@Test func privacyPolicyEnglish_coversAppProcessingAndArt13() throws {
    let html = try legalFile("en/privacy.html")
    for needle in [
        "Art. 6(1)",
        "supervisory authority",
        "date of birth",
        "MapKit",
        "time zone",
        "installed",
        "consent",
        "Retention",
        "minors",
        "automatically",
        "stack",
        "IP address",
        "subprocessors",
        "cookie banner",
        "Standard Contractual Clauses",
        "Paste import",
        "Private Cloud Compute",
        "ephemeral",
        "feature request",
        "confirmation",
        "public",
    ] {
        #expect(html.localizedCaseInsensitiveContains(needle), "en/privacy.html missing \(needle)")
    }
}

@Test func impressumGerman_linksConfidentialContactAndSeparatesAppLicense() throws {
    let html = try legalFile("impressum.html")
    #expect(html.contains(GitHubRepository.privacyRequestPage))
    #expect(html.contains(GitHubRepository.contactIssuePage))
    #expect(html.contains("App Store"))
    #expect(html.contains("CC BY-NC"))
    #expect(html.contains("kostenlos"))
    #expect(html.contains("§ 5 DDG"))
    #expect(html.contains("nicht-kommerzielle"))
    #expect(html.contains("geschäftsmäßig"))
    let english = try legalFile("en/impressum.html")
    #expect(english.contains("§ 5 DDG"))
    #expect(english.localizedCaseInsensitiveContains("non-commercial"))
    #expect(english.localizedCaseInsensitiveContains("business-like"))
}

@Test func legalPages_useGitHubRepositoryIssueURLs() throws {
    #expect(htmlContainsURL(try legalFile(GitHubRepository.privacyRequestPage), GitHubRepository.privacyRequestIssueURL))
    #expect(htmlContainsURL(try legalFile(GitHubRepository.contactIssuePage), GitHubRepository.contactIssueURL))
    for relative in ["privacy.html", "impressum.html"] {
        let html = try legalFile(relative)
        #expect(html.contains(GitHubRepository.privacyRequestPage), "\(relative) missing privacy-request link")
    }
    #expect(try legalFile("impressum.html").contains(GitHubRepository.contactIssuePage))
    for relative in ["en/privacy.html", "en/impressum.html"] {
        let html = try legalFile(relative)
        #expect(html.contains("../\(GitHubRepository.privacyRequestPage)"), "\(relative) missing privacy-request link")
    }
    #expect(try legalFile("en/impressum.html").contains("../\(GitHubRepository.contactIssuePage)"))
}

@Test func productPageGerman_separatesAppUseFromSourceLicense() throws {
    let html = try legalFile("index.html")
    #expect(html.contains("Quellcode"))
    #expect(html.contains("CC BY-NC"))
    #expect(html.contains("kostenlos"))
}
