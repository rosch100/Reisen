import Foundation

extension PersistenceBootstrap {
    nonisolated public static func isCloudKitEnabledByEnvironment() -> Bool {
        let env = ProcessInfo.processInfo.environment
        if env["REISEN_CLOUDKIT"] == "0" { return false }
        if env["CI"] == "true" { return false }
        // XCTest host processes must not open CloudKit (push entitlement / account noise).
        if env["XCTestConfigurationFilePath"] != nil { return false }
        return true
    }
}
