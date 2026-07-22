import Foundation

/// Canonical provider account credentials (read-only usage in this app).
public struct ProviderCredentials: Sendable, Equatable {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

