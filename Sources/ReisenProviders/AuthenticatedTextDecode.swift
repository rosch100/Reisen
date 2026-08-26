import Foundation

public enum AuthenticatedTextDecode {
    public static func utf8Text(data: Data, response: URLResponse) throws -> String {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            throw AuthenticatedFetchError.httpStatus(status)
        }
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            throw AuthenticatedFetchError.emptyBody
        }
        return text
    }
}
