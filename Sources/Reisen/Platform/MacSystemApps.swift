import AppKit
import Foundation

/// Öffnet System-Apps für Credential-Hilfsflows (Passwords / Schlüsselbundverwaltung).
enum MacSystemApps {
    @discardableResult
    static func openPasswords() -> Bool {
        openApplication(atCandidates: [
            "/System/Applications/Passwords.app",
            "/Applications/Passwords.app",
        ])
    }

    @discardableResult
    static func openKeychainAccess() -> Bool {
        openApplication(atCandidates: [
            "/System/Library/CoreServices/Applications/Keychain Access.app",
            "/Applications/Utilities/Keychain Access.app",
        ])
    }

    @discardableResult
    private static func openApplication(atCandidates paths: [String]) -> Bool {
        let candidates = paths.map { URL(fileURLWithPath: $0) }
        guard let appURL = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            return false
        }
        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        return true
    }
}
