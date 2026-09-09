import Foundation

/// Gemeinsame Keychain Access Group für macOS ↔ iOS Private Credential-Sync.
///
/// Ohne gemeinsame Group landen `kSecAttrSynchronizable`-Items in `TeamID.BundleID`
/// und sind zwischen `app.voyenna.reisen` und `app.voyenna.reisen.ios.private` unsichtbar.
/// Entitlement: `keychain-access-groups` = `$(AppIdentifierPrefix)` + `entitlementSuffix`.
/// Team-ID-SSOT: `project.yml` `DEVELOPMENT_TEAM`.
public enum KeychainCredentialAccessGroup: Sendable {
    public static let entitlementSuffix = "app.voyenna.reisen.shared-credentials"

    /// Volle Access-Group für SecItem-Queries (`TeamID.` + Suffix).
    public static let value = "4N6AJL9EX5.\(entitlementSuffix)"
}
