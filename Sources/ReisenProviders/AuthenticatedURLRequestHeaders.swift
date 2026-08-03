import Foundation

public enum AuthenticatedURLRequestHeaders {
    public static func applyOptionalHeaders(
        _ request: inout URLRequest,
        referer: String?,
        contentType: String?,
        headers: [String: String]
    ) {
        if let referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
    }
}
