import Foundation

internal enum KeychainCredentialAccountSort {
    static func sorted(_ accounts: [KeychainCredentialAccount]) -> [KeychainCredentialAccount] {
        accounts.sorted {
            if $0.username != $1.username {
                return $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending
            }
            return $0.serverHost.localizedCaseInsensitiveCompare($1.serverHost) == .orderedAscending
        }
    }
}
