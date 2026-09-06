import Foundation

/// Hosts for third-party IdP / social login that must not be treated as
/// provider account pages or receive Keychain password autofill.
public enum AuthIdentityProviderHost {
    public static func matches(_ host: String) -> Bool {
        let h = host.lowercased()
        if matchesApple(h) { return true }
        if h == "google.com" || h.hasSuffix(".google.com") { return true }
        if h == "accounts.google.com" { return true }
        if h == "facebook.com" || h.hasSuffix(".facebook.com") { return true }
        if h == "fb.com" || h.hasSuffix(".fb.com") { return true }
        return false
    }

    public static func matchesApple(urlAbsoluteString: String) -> Bool {
        guard let host = URL(string: urlAbsoluteString)?.host else { return false }
        return matchesApple(host)
    }

    /// Sync-Banner: Passkey-Hinweis nur bei Apple-IdP während Login.
    public static func showsApplePasskeyHint(
        needsLogin: Bool,
        urlAbsoluteString: String?,
        authPopupURLAbsoluteString: String? = nil
    ) -> Bool {
        guard needsLogin else { return false }
        if let authPopupURLAbsoluteString, matchesApple(urlAbsoluteString: authPopupURLAbsoluteString) {
            return true
        }
        guard let urlAbsoluteString else { return false }
        return matchesApple(urlAbsoluteString: urlAbsoluteString)
    }

    public static func matches(urlAbsoluteString: String) -> Bool {
        guard let host = URL(string: urlAbsoluteString)?.host else { return false }
        return matches(host)
    }

    private static func matchesApple(_ host: String) -> Bool {
        host == "apple.com"
            || host.hasSuffix(".apple.com")
            || host == "appleid.apple.com"
            || host.hasSuffix(".appleid.apple.com")
    }
}
