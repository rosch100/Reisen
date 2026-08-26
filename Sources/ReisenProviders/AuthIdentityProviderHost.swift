import Foundation

/// Hosts for third-party IdP / social login that must not be treated as
/// provider account pages or receive Keychain password autofill.
public enum AuthIdentityProviderHost {
    public static func matches(_ host: String) -> Bool {
        let h = host.lowercased()
        if h == "apple.com" || h.hasSuffix(".apple.com") { return true }
        if h == "appleid.apple.com" || h.hasSuffix(".appleid.apple.com") { return true }
        if h == "google.com" || h.hasSuffix(".google.com") { return true }
        if h == "accounts.google.com" { return true }
        if h == "facebook.com" || h.hasSuffix(".facebook.com") { return true }
        if h == "fb.com" || h.hasSuffix(".fb.com") { return true }
        return false
    }

    public static func matches(urlAbsoluteString: String) -> Bool {
        guard let host = URL(string: urlAbsoluteString)?.host else { return false }
        return matches(host)
    }
}
