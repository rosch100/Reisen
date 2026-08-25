import Foundation

extension PersistenceBootstrap {
    nonisolated public static func isCloudKitEnabledByEnvironment() -> Bool {
        let env = ProcessInfo.processInfo.environment
        if env["REISEN_CLOUDKIT"] == "0" { return false }
        if env["CI"] == "true" { return false }
        // XCTest host processes must not open CloudKit (push entitlement / account noise).
        if env["XCTestConfigurationFilePath"] != nil { return false }
        // Swift Testing via `swift test` (swiftpm-testing-helper; no XCTest env).
        if ProcessInfo.processInfo.processName == "swiftpm-testing-helper" { return false }
        if CommandLine.arguments.contains("--test-bundle-path") { return false }
        return true
    }
}
