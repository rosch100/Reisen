import Testing
import Foundation
@testable import ReisenAppCore
import ReisenDomain

@Test func githubIssueNewIssueURL_usesTemplateLabelsAndFormField() throws {
    let url = try #require(
        GitHubIssueNewIssueURL.compose(
            kind: .feedback,
            message: "Hallo Welt",
            providerID: nil
        )
    )
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let query = try #require(components.queryItems)
    let title = try #require(query.first { $0.name == "title" }?.value)
    let template = try #require(query.first { $0.name == "template" }?.value)
    let labels = try #require(query.first { $0.name == "labels" }?.value)
    let feedback = try #require(query.first { $0.name == "feedback" }?.value)
    #expect(title == "[Feedback] Hallo Welt")
    #expect(template == "feedback.yml")
    #expect(labels == "kind/feedback,source/in-app")
    #expect(feedback.contains("Hallo Welt"))
    #expect(feedback.contains("| Art | Feedback |"))
    #expect(feedback.contains("| Quelle | In-App |"))
    #expect(query.contains { $0.name == "body" } == false)
    #expect(url.host == "github.com")
    #expect(url.path.contains("/issues/new"))
}

@Test func githubIssueNewIssueURL_bugUsesWhatFieldAndUserOrigin() throws {
    let url = try #require(
        GitHubIssueNewIssueURL.compose(
            kind: .error,
            message: "Timeout",
            providerID: .opodo,
            githubUsername: "rosch100"
        )
    )
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let query = try #require(components.queryItems)
    let template = try #require(query.first { $0.name == "template" }?.value)
    let labels = try #require(query.first { $0.name == "labels" }?.value)
    let what = try #require(query.first { $0.name == "what" }?.value)
    #expect(template == "bug.yml")
    #expect(labels == "kind/error,source/in-app")
    #expect(what.contains("Timeout"))
    #expect(what.contains("| Art | Fehler |"))
    #expect(what.contains("| Meldeweg | GitHub-Konto |"))
    #expect(what.contains("| GitHub-Nutzer | @rosch100 |"))
}

@Test func githubIssueNewIssueURL_truncatesLongFormField() {
    let longMessage = String(repeating: "A", count: 12_000)
    let value = GitHubIssueNewIssueURL.formFieldValueForQuery(
        kind: .error,
        title: "[Fehler] lang",
        message: longMessage,
        providerID: nil,
        origin: .embeddedToken(attributedUsername: nil),
    )
    #expect(value.count <= GitHubIssueNewIssueURL.maxBodyCharacterCount)
    #expect(value.contains("gekürzt"))
    #expect(
        GitHubIssueNewIssueURL.fitsInIssueURL(
            kind: .error,
            title: "[Fehler] lang",
            formFieldValue: value
        )
    )
}

@Test func githubIssueNewIssueURL_fitsWithinMaxURLLength() throws {
    let longMessage = String(repeating: "äöü ", count: 4_000)
    let url = try #require(
        GitHubIssueNewIssueURL.compose(
            kind: .error,
            message: longMessage,
            providerID: nil
        )
    )
    #expect(url.absoluteString.count <= GitHubIssueNewIssueURL.maxURLLength)
}

@Test func githubIssueToken_isNotEmbeddedInStubBuild() {
    #expect(GitHubIssueToken.isEmbedded == false)
}
