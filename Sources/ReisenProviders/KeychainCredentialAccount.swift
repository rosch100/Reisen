import Foundation

/// Lesbarer Keychain-Account ohne Secret (für Auswahl-UI).
public struct KeychainCredentialAccount: Hashable, Sendable, Identifiable {
    public var id: String { "\(serverHost)\u{1f}\(username)" }

    public let serverHost: String
    public let username: String

    public init(serverHost: String, username: String) {
        self.serverHost = serverHost
        self.username = username
    }

    public var displayTitle: String { username }

    public var displaySubtitle: String { serverHost }
}
