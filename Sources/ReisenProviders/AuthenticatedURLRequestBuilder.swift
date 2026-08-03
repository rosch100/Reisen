import Foundation

public enum AuthenticatedURLRequestBuilder {
    public static func baseRequest(
        url: URL,
        method: String,
        accept: String,
        referer: String?,
        contentType: String?,
        body: Data?,
        headers: [String: String]
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(accept, forHTTPHeaderField: "Accept")
        AuthenticatedURLRequestHeaders.applyOptionalHeaders(
            &request,
            referer: referer,
            contentType: contentType,
            headers: headers
        )
        request.httpBody = body
        return request
    }

    public static func applyCookieHeader(_ request: inout URLRequest, cookies: [HTTPCookie], url: URL) {
        let matching = cookies.filter { HTTPCookieHostMatching.matches($0, url: url) }
        guard !matching.isEmpty else { return }
        let header = matching.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        request.setValue(header, forHTTPHeaderField: "Cookie")
    }
}
