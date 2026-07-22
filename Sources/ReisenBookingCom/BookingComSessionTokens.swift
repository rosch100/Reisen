import Foundation

public struct BookingComSessionTokens: Equatable, Sendable {
    public var csrfToken: String
    public var apolloClientVersion: String

    public init(csrfToken: String, apolloClientVersion: String) {
        self.csrfToken = csrfToken
        self.apolloClientVersion = apolloClientVersion
    }

    public static func extract(from html: String) throws -> BookingComSessionTokens {
        guard let csrfToken = BookingComParsing.capture(
            #""csrfToken"\s*:\s*"(eyJ[^"]+)""#,
            in: html
        ) else {
            throw BookingComProviderError.sessionTokensMissing
        }

        // Trip-XP MFE is current (HAR 2026-07); wishlist MFE may still appear on older pages.
        guard let apolloClientVersion = BookingComParsing.capture(
            #"b-trips-frontend-trip-xp-mfe([A-Za-z0-9]+)"#,
            in: html
        ) ?? BookingComParsing.capture(
            #"b-wishlist-wishlist-mfe([A-Za-z0-9]+)"#,
            in: html
        ) else {
            throw BookingComProviderError.sessionTokensMissing
        }

        return BookingComSessionTokens(
            csrfToken: csrfToken,
            apolloClientVersion: apolloClientVersion
        )
    }
}
