import Foundation
import ReisenDomain

public final class GitHubIssueAPIClient: GitHubIssueSubmitting, Sendable {
    private let tokenProvider: @Sendable () throws -> String
    private let session: URLSession

    public init(
        tokenProvider: @escaping @Sendable () throws -> String,
        session: URLSession = .shared
    ) {
        self.tokenProvider = tokenProvider
        self.session = session
    }

    static func restHeaders(token: String) -> [String: String] {
        [
            "Accept": "application/vnd.github+json",
            "Authorization": "Bearer \(token)",
            "X-GitHub-Api-Version": GitHubRepository.restAPIVersion,
            "User-Agent": GitHubRepository.restUserAgent,
        ]
    }

    public func searchOpenFingerprint(_ fingerprint: String) async throws -> Int? {
        guard let url = GitHubRepository.searchOpenIssuesURL(fingerprint: fingerprint) else {
            throw GitHubIssueAPIClientError.invalidURL
        }
        let data = try await request(url: url, method: "GET", body: Optional<NeverEncodable>.none)
        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        return decoded.items.first?.number
    }

    public func createIssue(title: String, body: String, labels: [String]) async throws -> GitHubCreatedIssue {
        let payload = CreatePayload(title: title, body: body, labels: labels)
        let data = try await request(url: GitHubRepository.apiIssuesURL, method: "POST", body: payload)
        let decoded = try JSONDecoder().decode(IssueResponse.self, from: data)
        return GitHubCreatedIssue(number: decoded.number, htmlURL: decoded.htmlURL)
    }

    public func comment(issueNumber: Int, body: String) async throws -> GitHubCreatedIssue {
        let url = GitHubRepository.apiIssuesURL
            .appending(path: String(issueNumber))
            .appending(path: "comments")
        let payload = CommentPayload(body: body)
        _ = try await request(url: url, method: "POST", body: payload)
        return GitHubCreatedIssue(
            number: issueNumber,
            htmlURL: GitHubRepository.issueURL(number: issueNumber)
        )
    }

    private func request<Body: Encodable>(url: URL, method: String, body: Body?) async throws -> Data {
        let token = try tokenProvider()
        var request = URLRequest(url: url)
        request.httpMethod = method
        for (header, value) in Self.restHeaders(token: token) {
            request.setValue(value, forHTTPHeaderField: header)
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GitHubIssueAPIClientError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw GitHubIssueAPIClientError.httpFailure(status: http.statusCode, data: data)
        }
        return data
    }

    private struct SearchResponse: Decodable {
        let items: [IssueResponse]
    }

    private struct IssueResponse: Decodable {
        let number: Int
        let htmlURL: URL

        enum CodingKeys: String, CodingKey {
            case number
            case htmlURL = "html_url"
        }
    }

    private struct CreatePayload: Encodable {
        let title: String
        let body: String
        let labels: [String]
    }

    private struct CommentPayload: Encodable {
        let body: String
    }

    private struct NeverEncodable: Encodable {}
}

public enum GitHubIssueAPIClientError: Error, Equatable, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int, snippet: String)

    public static func httpFailure(status: Int, data: Data) -> GitHubIssueAPIClientError {
        let raw = String(data: data, encoding: .utf8) ?? ""
        let snippet = String(SecretRedactor.redact(raw).prefix(300))
        return .httpStatus(status, snippet: snippet)
    }

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "GitHub-Issue-URL ungültig"
        case .invalidResponse:
            return "GitHub-Issue-Antwort ungültig"
        case .httpStatus(let code, let snippet):
            if snippet.isEmpty {
                return "GitHub-Issue-HTTP \(code)"
            }
            return "GitHub-Issue-HTTP \(code): \(snippet)"
        }
    }
}
