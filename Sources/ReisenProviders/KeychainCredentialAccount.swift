import Foundation

/// Lesbarer Keychain-Account ohne Secret (für Auswahl-UI).
public struct KeychainCredentialAccount: Hashable, Sendable, Identifiable {
    private static let idSeparator: Character = "\u{1f}"

    public static func makeID(serverHost: String, username: String) -> String {
        "\(serverHost)\(idSeparator)\(username)"
    }

    public static func parseID(_ raw: String) -> (serverHost: String, username: String)? {
        let parts = raw.split(separator: idSeparator, maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let serverHost = String(parts[0])
        let username = String(parts[1])
        guard !serverHost.isEmpty, !username.isEmpty else { return nil }
        return (serverHost, username)
    }

    public var id: String { Self.makeID(serverHost: serverHost, username: username) }

    public let serverHost: String
    public let username: String

    public init(serverHost: String, username: String) {
        self.serverHost = serverHost
        self.username = username
    }

    public var displayTitle: String { username }

    public var displaySubtitle: String { serverHost }
}
