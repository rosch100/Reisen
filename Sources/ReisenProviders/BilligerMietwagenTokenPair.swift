import Foundation
import ReisenDomain

/// Session- und Refresh-Antwort teilen dasselbe Token-Shape (Probe + Sync).
public struct BilligerMietwagenTokenPair: Decodable, Sendable {
    public let accessToken: String?
    public let refreshToken: String?

    private static let unauthenticated = BilligerMietwagenTokenPair(accessToken: nil, refreshToken: nil)

    public init(accessToken: String?, refreshToken: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FieldKey.self)
        accessToken = try container.decodeIfPresent(
            String.self,
            forKey: FieldKey(BilligerMietwagenAuthConstants.accessTokenField)
        )
        refreshToken = try container.decodeIfPresent(
            String.self,
            forKey: FieldKey(BilligerMietwagenAuthConstants.refreshTokenField)
        )
    }

    public var hasSessionTokens: Bool {
        NonEmpty.string(accessToken) != nil && NonEmpty.string(refreshToken) != nil
    }

    public static func parseSession(from jsonText: String) throws -> BilligerMietwagenTokenPair {
        if BilligerMietwagenAuthConstants.isEmptySessionPayload(jsonText) {
            return unauthenticated
        }
        let trimmed = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(trimmed.utf8)
        let value = try JSONSerialization.jsonObject(with: data)
        if value is [Any] {
            return unauthenticated
        }
        return try decode(data)
    }

    public static func parseRefresh(from jsonText: String) throws -> BilligerMietwagenTokenPair {
        try decode(Data(jsonText.utf8))
    }

    private static func decode(_ data: Data) throws -> BilligerMietwagenTokenPair {
        try JSONDecoder().decode(BilligerMietwagenTokenPair.self, from: data)
    }

    private struct FieldKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }

        init(_ stringValue: String) {
            self.stringValue = stringValue
        }

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            return nil
        }
    }
}
