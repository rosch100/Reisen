import Foundation
import Security

/// Entitlements des laufenden Prozesses, wie sie in der Code-Signatur stehen.
enum ProcessEntitlements {
    /// Managed Entitlement für Apple Private Cloud Compute.
    ///
    /// Ohne diesen Key darf die App PCC nicht nutzen — `PrivateCloudComputeLanguageModel.availability`
    /// kann trotzdem `.available` sein (Gerät/OS), `respond` bricht dann ab oder trappt.
    static let privateCloudCompute = "com.apple.developer.private-cloud-compute"

    static func contains(_ key: String) -> Bool {
        var code: SecCode?
        guard SecCodeCopySelf(SecCSFlags(), &code) == errSecSuccess, let code else {
            return false
        }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, SecCSFlags(), &staticCode) == errSecSuccess,
              let staticCode
        else {
            return false
        }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &info
        ) == errSecSuccess, let info else {
            return false
        }
        let entitlements = (info as NSDictionary)[kSecCodeInfoEntitlementsDict] as? [String: Any]
        return entitlements?[key] != nil
    }
}
