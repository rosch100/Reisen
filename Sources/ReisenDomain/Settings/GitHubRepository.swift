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
        case impressum

        fileprivate func page(german: Bool) -> LegalPage {
            switch self {
            case .privacy: german ? .privacyDE : .privacyEN
            case .support: german ? .supportDE : .supportEN
            case .impressum: german ? .impressumDE : .impressumEN
            }
        }
    }

    public enum LegalPage: String, Sendable, CaseIterable {
        case privacyDE = "privacy.html"
        case privacyEN = "en/privacy.html"
        case supportDE = "support.html"
        case supportEN = "en/support.html"
        case impressumDE = "impressum.html"
        case impressumEN = "en/impressum.html"

        /// GitHub-Pages-Pfad = Inhaltspfad unter `docs/legal/` (EN unter `en/`).
        /// Legacy-Stubs `*.en.html` am Site-Root leiten per Meta-Refresh hierher.
        public var pagesPath: String { rawValue }
    }

    public static let privacyRequestPage = "privacy-request.html"
    public static let contactIssuePage = "contact-request.html"

    /// Öffentliche Projekt-Mail (Impressum, Support, Gmail-Ingress). Kein Secret.
    public static let feedbackEmail = "reisenapp100@gmail.com"

    public static var feedbackMailtoURL: URL {
        guard let url = URL(string: "mailto:\(feedbackEmail)") else {
            preconditionFailure("feedbackEmail muss eine gültige mailto-URL ergeben.")
        }
        return url
    }

    public static var publicPath: String {
        "\(owner)/\(name)"
    }

    public static var webBaseURL: URL {
        URL(string: "https://github.com/\(publicPath)")!
    }

    public static var apiRepoURL: URL {
        URL(string: "https://api.github.com/repos/\(publicPath)")!
    }

    public static var apiIssuesURL: URL {
        apiRepoURL.appending(path: "issues")
    }

    /// GitHub REST: `X-GitHub-Api-Version` (https://docs.github.com/en/rest).
    public static let restAPIVersion = "2022-11-28"
    /// GitHub REST: Pflicht-`User-Agent` (Anwendungsname).
    public static let restUserAgent = "Reisen"
    /// GitHub-Validierung: `title is too long (maximum is 256 characters)`.
    public static let issueTitleMaxLength = 256
    /// Kürzung der Titel-Zusammenfassung (erste Zeile / Betreff) vor dem API-Limit.
    public static let issueTitleSummaryMaxLength = 80
    /// GitHub-Validierung: `body is too long (maximum is 65536 characters)` (Issues und Kommentare).
    public static let issueBodyMaxLength = 65_536
    /// Markdown-`## `-Abschnitte (Clamp an Heading-Grenzen, App + Gmail-Ingress).
    public static let issueMarkdownH2Prefix = "## "
    /// `{email}` wird durch `feedbackEmail` ersetzt (App + Gmail-Ingress).
    public static let issueBodyTruncationNoticeTemplate = "… (Text gekürzt — GitHub-Issue-Limit. Vollständige Dateien per E-Mail an {email}.)"
    public static var issueBodyTruncationNotice: String {
        filledEmail(issueBodyTruncationNoticeTemplate)
    }
    public static let issueAttachmentPolicyCellTemplate = "nicht auf GitHub; Dateien per E-Mail an {email}"
    public static var issueAttachmentPolicyCell: String {
        filledEmail(issueAttachmentPolicyCellTemplate)
    }

    private static func filledEmail(_ template: String) -> String {
        template.replacingOccurrences(of: "{email}", with: feedbackEmail)
    }
    /// Search-API: Suchbegriff ohne Operatoren max. 256 Zeichen.
    public static let issueSearchKeywordMaxLength = 256

    public static var issuesListURL: URL {
        webBaseURL.appending(path: "issues")
    }

    public static var newIssueFormURL: URL {
        issuesListURL.appending(path: "new")
    }

    public static var pagesBaseURL: URL {
        URL(string: "https://\(owner).github.io/\(name)")!
    }

    /// Trailing slash für Site-Root-URLs (404-Assets, Navigation).
    public static var pagesSiteRootURL: URL {
        URL(string: pagesBaseURL.absoluteString + "/")!
    }

    /// Private Security Advisory (SSOT mit `SECURITY.md`, `CODE_OF_CONDUCT.md`, Issue-Formulare).
    public static var securityAdvisoryNewURL: URL {
        webBaseURL.appending(path: "security/advisories/new")
    }

    /// Übersicht Security Advisories.
    public static var securityAdvisoriesURL: URL {
        webBaseURL.appending(path: "security/advisories")
    }

    /// Vorausgefülltes Issue ohne personenbezogene Angaben im öffentlichen Text.
    /// SSOT mit `.github/ISSUE_TEMPLATE/legal.yml` Feld `notice` (`value:`).
    public static let publicIssueNoPersonalDataBody = """
        Bitte keine Reisedaten, Passagierdaten, E-Mail-Adressen, Postanschriften oder sonstigen personenbezogenen Angaben in dieses Issue schreiben. Wir antworten mit einem privaten Kontaktweg.

        Please do not include trip, passenger, email, postal, or other personal data in this issue. We will reply with a private contact channel.
        """

    /// Issue-Formular für Kontakt-/Datenschutz-Links (SSOT mit `legal.yml`).
    public static let legalIssueTemplateFileName = "legal.yml"
    public static let legalIssueFormFieldID = "notice"
    /// Titelpräfix (SSOT mit `legal.yml` `title:`).
    public static let legalIssueTitlePrefix = "[Kontakt]"

    /// Vorausgefülltes Issue für Impressum-/Kontaktanfragen (Website).
    public static var contactIssueURL: URL {
        publicIssue(title: "\(legalIssueTitlePrefix) Impressum / Legal contact")
    }

    /// Datenschutzanfrage ohne Reisedaten im öffentlichen Issue-Text.
    public static var privacyRequestIssueURL: URL {
        publicIssue(title: "\(legalIssueTitlePrefix) Datenschutzanfrage / Privacy request")
    }

    private static var apiSearchIssuesURL: URL {
        URL(string: "https://api.github.com/search/issues")!
    }

    public static func searchOpenIssuesURL(fingerprint: String) -> URL? {
        url(from: apiSearchIssuesURL, queryItems: [
            URLQueryItem(
                name: "q",
                value: "repo:\(publicPath) is:issue state:open in:body \(fingerprint)"
            ),
        ])
    }

    public static func newIssueURL(queryItems: [URLQueryItem]) -> URL? {
        url(from: newIssueFormURL, queryItems: queryItems)
    }

    public static func newIssueURL(title: String, body: String) -> URL {
        guard let url = newIssueURL(queryItems: [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "body", value: body),
        ]) else {
            preconditionFailure("GitHub-Issue-URL aus gültiger Formular-URL muss konstruierbar sein.")
        }
        return url
    }

    /// New-Issue-URL für YAML-Formular mit vorausgefülltem Feld (kein Query-`body`).
    public static func newIssueURL(
        templateFileName: String,
        title: String,
        formFieldID: String,
        formFieldValue: String
    ) -> URL {
        guard let url = newIssueURL(queryItems: [
            URLQueryItem(name: "template", value: templateFileName),
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: formFieldID, value: formFieldValue),
        ]) else {
            preconditionFailure("GitHub-Issue-URL aus gültiger Formular-URL muss konstruierbar sein.")
        }
        return url
    }

    /// `href`/`url=` in statischem HTML (`&` → `&amp;`).
    public static func htmlEncodedURL(_ url: URL) -> String {
        url.absoluteString.replacingOccurrences(of: "&", with: "&amp;")
    }

    public static func issueURL(number: Int) -> URL {
        issuesListURL.appending(path: String(number))
    }

    public static func legalPage(for document: LegalDocument, locale: Locale = .current) -> LegalPage {
        document.page(german: locale.reisenPrefersGerman)
    }

    public static func rawLegalURL(_ page: LegalPage) -> URL {
        URL(
            string: "https://raw.githubusercontent.com/\(publicPath)/\(defaultBranch)/\(legalDirectory)/\(page.rawValue)"
        )!
    }

    public static func pagesLegalURL(_ page: LegalPage) -> URL {
        URL(string: "\(pagesBaseURL.absoluteString)/\(page.pagesPath)")!
    }

    public static func pagesLegalURL(for document: LegalDocument, locale: Locale = .current) -> URL {
        pagesLegalURL(legalPage(for: document, locale: locale))
    }

    public static func rawLegalURL(for document: LegalDocument, locale: Locale = .current) -> URL {
        rawLegalURL(legalPage(for: document, locale: locale))
    }

    private static func publicIssue(title: String) -> URL {
        newIssueURL(
            templateFileName: legalIssueTemplateFileName,
            title: title,
            formFieldID: legalIssueFormFieldID,
            formFieldValue: publicIssueNoPersonalDataBody
        )
    }

    private static func url(from base: URL, queryItems: [URLQueryItem]) -> URL? {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = queryItems
        return components.url
    }
}
