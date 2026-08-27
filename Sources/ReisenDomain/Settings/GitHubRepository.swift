import Foundation

/// SSOT für das öffentliche GitHub-Repository (Issues, Raw-Legal, Pages).
public enum GitHubRepository {
    public static let owner = "rosch100"
    public static let name = "Reisen"
    public static let defaultBranch = "master"
    public static let legalDirectory = "docs/legal"

    public enum LegalDocument: Sendable {
        case privacy
        case support
    }

    public enum LegalPage: String, Sendable {
        case privacyDE = "privacy.html"
        case privacyEN = "en/privacy.html"
        case supportDE = "support.html"
        case supportEN = "en/support.html"
    }

    public static var webBaseURL: URL {
        URL(string: "https://github.com/\(owner)/\(name)")!
    }

    public static var issuesListURL: URL {
        webBaseURL.appending(path: "issues")
    }

    public static var newIssuePath: String {
        "/\(owner)/\(name)/issues/new"
    }

    public static var pagesBaseURL: URL {
        URL(string: "https://\(owner).github.io/\(name)")!
    }

    public static var apiRepoURL: URL {
        URL(string: "https://api.github.com/repos/\(owner)/\(name)")!
    }

    public static func issueURL(number: Int) -> URL {
        issuesListURL.appending(path: String(number))
    }

    public static func legalPage(for document: LegalDocument, locale: Locale = .current) -> LegalPage {
        let isGerman = locale.reisenPrefersGerman
        switch document {
        case .privacy:
            return isGerman ? .privacyDE : .privacyEN
        case .support:
            return isGerman ? .supportDE : .supportEN
        }
    }

    public static func rawLegalURL(_ page: LegalPage) -> URL {
        URL(
            string: "https://raw.githubusercontent.com/\(owner)/\(name)/\(defaultBranch)/\(legalDirectory)/\(page.rawValue)"
        )!
    }

    public static func pagesLegalURL(_ page: LegalPage) -> URL {
        pagesBaseURL.appending(path: page.rawValue)
    }

    public static func pagesLegalURL(for document: LegalDocument, locale: Locale = .current) -> URL {
        pagesLegalURL(legalPage(for: document, locale: locale))
    }

    public static func rawLegalURL(for document: LegalDocument, locale: Locale = .current) -> URL {
        rawLegalURL(legalPage(for: document, locale: locale))
    }

    public static var publicPath: String {
        "\(owner)/\(name)"
    }
}
