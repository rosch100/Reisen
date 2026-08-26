import Testing
import Foundation
@testable import ReisenAppCore
import ReisenDomain

@Test func githubIssueNewIssueURL_containsTitleAndBody() throws {
    let url = try #require(
        GitHubIssueNewIssueURL.compose(
            kind: .feedback,
            title: "Reisen-Feedback: Test",
            message: "Hallo Welt",
            providerID: nil
        )
    )
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let query = try #require(components.queryItems)
    let title = try #require(query.first { $0.name == "title" }?.value)
    let body = try #require(query.first { $0.name == "body" }?.value)
    #expect(title.contains("Reisen-Feedback"))
    #expect(body.contains("Hallo Welt"))
    #expect(url.host == "github.com")
    #expect(url.path.contains("/issues/new"))
}

@Test func githubIssueNewIssueURL_truncatesLongBody() {
    let longMessage = String(repeating: "A", count: 12_000)
    let body = GitHubIssueNewIssueURL.bodyForQuery(
        kind: .error,
        title: "Reisen-Fehler: lang",
        message: longMessage,
        providerID: nil
    )
    #expect(body.count <= GitHubIssueNewIssueURL.maxBodyCharacterCount)
    #expect(body.contains("gekürzt"))
    #expect(
        GitHubIssueNewIssueURL.fitsInIssueURL(
            title: "Reisen-Fehler: lang",
            body: body
        )
    )
}

@Test func githubIssueNewIssueURL_fitsWithinMaxURLLength() throws {
    let longMessage = String(repeating: "äöü ", count: 4_000)
    let url = try #require(
        GitHubIssueNewIssueURL.compose(
            kind: .error,
            title: "Reisen-Fehler: encodiert",
            message: longMessage,
            providerID: nil
        )
    )
    #expect(url.absoluteString.count <= GitHubIssueNewIssueURL.maxURLLength)
}

@Test func githubIssueToken_isNotEmbeddedInStubBuild() {
    #expect(GitHubIssueToken.isEmbedded == false)
}
