import Foundation

/// SSOT für das öffentliche GitHub-Repository (Issues, Raw-Legal, Pages).
public enum GitHubRepository {
    public static let owner = "rosch100"
    public static let name = "Reisen"
    public static let defaultBranch = "master"
    public static let legalDirectory = "docs/legal"

    public enum LegalPage: String {
        case privacy = "privacy.html"
        case support = "support.html"
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

    public static func rawLegalURL(_ page: LegalPage) -> URL {
        URL(
            string: "https://raw.githubusercontent.com/\(owner)/\(name)/\(defaultBranch)/\(legalDirectory)/\(page.rawValue)"
        )!
    }

    public static func pagesLegalURL(_ page: LegalPage) -> URL {
        pagesBaseURL.appending(path: page.rawValue)
    }

    public static var publicPath: String {
        "\(owner)/\(name)"
    }
}
