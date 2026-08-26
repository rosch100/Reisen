import Foundation

public enum GitHubIssueTokenError: Error, Equatable, LocalizedError {
    case notEmbedded
    case keyEmpty
    case invalidUTF8

    public var errorDescription: String? {
        switch self {
        case .notEmbedded:
            return "Issue-Token nicht eingebettet"
        case .keyEmpty:
            return "Issue-Token-Schlüssel fehlt"
        case .invalidUTF8:
            return "Issue-Token ist kein gültiges UTF-8"
        }
    }
}

enum GitHubIssueTokenCodec {
    static func decode(bytes: [UInt8], key: [UInt8]) throws -> String {
        guard !bytes.isEmpty else { throw GitHubIssueTokenError.notEmbedded }
        guard !key.isEmpty else { throw GitHubIssueTokenError.keyEmpty }
        let decoded = bytes.enumerated().map { offset, byte in
            byte ^ key[offset % key.count]
        }
        guard let value = String(bytes: decoded, encoding: .utf8), !value.isEmpty else {
            throw GitHubIssueTokenError.invalidUTF8
        }
        return value
    }
}

public enum GitHubIssueToken {
    public static var isEmbedded: Bool {
        !GitHubIssueTokenPayload.bytes.isEmpty
    }

    public static func value() throws -> String {
        try GitHubIssueTokenCodec.decode(
            bytes: GitHubIssueTokenPayload.bytes,
            key: GitHubIssueTokenPayload.key
        )
    }
}
