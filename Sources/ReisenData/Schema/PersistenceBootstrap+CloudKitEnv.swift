import Foundation
#if os(macOS)
import Security
#endif

extension PersistenceBootstrap {
    /// Env/Entitlements only — ignores the user iCloud-sync preference.
    nonisolated public static func isCloudKitAllowedByEnvironmentProcess() -> Bool {
        isCloudKitAllowedByEnvironment(
            environment: ProcessInfo.processInfo.environment,
            processName: ProcessInfo.processInfo.processName,
            arguments: CommandLine.arguments,
            teamIdentifier: codeSigningTeamIdentifier(),
            applicationIdentifier: codeSigningApplicationIdentifier(),
            icloudContainerIdentifiers: codeSigningStringArrayEntitlement(
                "com.apple.developer.icloud-container-identifiers"
            ),
            icloudServices: codeSigningStringArrayEntitlement(
                "com.apple.developer.icloud-services"
            ),
            icloudContainerEnvironment: stringEntitlement(
                "com.apple.developer.icloud-container-environment"
            )
        )
    }

    /// Effective CloudKit: Env/Entitlements **and** caller-supplied user preference.
    /// Resolve `AppSettingsKeys.isICloudSyncEnabled()` outside ReisenData and pass it in.
    nonisolated public static func isCloudKitEnabledByEnvironment(
        iCloudSyncPreferenceEnabled: Bool
    ) -> Bool {
        isCloudKitEnabled(
            environment: ProcessInfo.processInfo.environment,
            processName: ProcessInfo.processInfo.processName,
            arguments: CommandLine.arguments,
            teamIdentifier: codeSigningTeamIdentifier(),
            applicationIdentifier: codeSigningApplicationIdentifier(),
            icloudContainerIdentifiers: codeSigningStringArrayEntitlement(
                "com.apple.developer.icloud-container-identifiers"
            ),
            icloudServices: codeSigningStringArrayEntitlement(
                "com.apple.developer.icloud-services"
            ),
            icloudContainerEnvironment: stringEntitlement(
                "com.apple.developer.icloud-container-environment"
            ),
            iCloudSyncPreferenceEnabled: iCloudSyncPreferenceEnabled
        )
    }

    /// CloudKit is off when the process cannot use it: CI/tests, explicit `REISEN_CLOUDKIT=0`,
    /// or (macOS) a signature that cannot open `CKContainer` (ad-hoc: no Team ID /
    /// `application-identifier`, missing iCloud/CloudKit entitlements, or
    /// `icloud-container-environment` not a single `Development`/`Production` string).
    /// An array copied from the provisioning profile still aborts CloudKit (`CKException`).
    /// Opening a CloudKit store or `CKContainer` without that aborts macOS (`_os_crash`).
    /// iOS Simulator/Device uses the platform signing path and does not apply that guard.
    /// User preference off (`iCloudSyncPreferenceEnabled == false`) also disables CloudKit.
    nonisolated public static func isCloudKitEnabled(
        environment: [String: String],
        processName: String,
        arguments: [String],
        teamIdentifier: String?,
        applicationIdentifier: String?,
        icloudContainerIdentifiers: [String],
        icloudServices: [String],
        icloudContainerEnvironment: String?,
        iCloudSyncPreferenceEnabled: Bool
    ) -> Bool {
        guard iCloudSyncPreferenceEnabled else { return false }
        return isCloudKitAllowedByEnvironment(
            environment: environment,
            processName: processName,
            arguments: arguments,
            teamIdentifier: teamIdentifier,
            applicationIdentifier: applicationIdentifier,
            icloudContainerIdentifiers: icloudContainerIdentifiers,
            icloudServices: icloudServices,
            icloudContainerEnvironment: icloudContainerEnvironment
        )
    }

    nonisolated public static func isCloudKitAllowedByEnvironment(
        environment: [String: String],
        processName: String,
        arguments: [String],
        teamIdentifier: String?,
        applicationIdentifier: String?,
        icloudContainerIdentifiers: [String],
        icloudServices: [String],
        icloudContainerEnvironment: String?
    ) -> Bool {
        if environment["REISEN_CLOUDKIT"] == "0" { return false }
        if environment["CI"] == "true" { return false }
        // XCTest host processes must not open CloudKit (push entitlement / account noise).
        if environment["XCTestConfigurationFilePath"] != nil { return false }
        // Swift Testing via `swift test` (swiftpm-testing-helper; no XCTest env).
        if processName == "swiftpm-testing-helper" { return false }
        if arguments.contains("--test-bundle-path") { return false }
        #if os(macOS)
        guard let teamIdentifier, !teamIdentifier.isEmpty else { return false }
        guard let applicationIdentifier, !applicationIdentifier.isEmpty else { return false }
        guard icloudContainerIdentifiers.contains(cloudKitContainerID) else { return false }
        guard allowsCloudKitService(icloudServices) else { return false }
        guard allowsCloudKitContainerEnvironment(icloudContainerEnvironment) else { return false }
        #else
        _ = teamIdentifier
        _ = applicationIdentifier
        _ = icloudContainerIdentifiers
        _ = icloudServices
        _ = icloudContainerEnvironment
        #endif
        return true
    }

    nonisolated static func allowsCloudKitService(_ services: [String]) -> Bool {
        services.contains(cloudKitServiceEntitlement) || services.contains("*")
    }

    nonisolated static func allowsCloudKitContainerEnvironment(_ environment: String?) -> Bool {
        environment == cloudKitContainerEnvironmentDevelopment
            || environment == cloudKitContainerEnvironmentProduction
    }

    nonisolated static func codeSigningTeamIdentifier() -> String? {
        #if os(macOS)
        let team = codeSigningInformation()?[kSecCodeInfoTeamIdentifier] as? String
        guard let team, !team.isEmpty else { return nil }
        return team
        #else
        return nil
        #endif
    }

    nonisolated static func codeSigningApplicationIdentifier() -> String? {
        stringEntitlement("com.apple.application-identifier")
    }

    nonisolated private static func codeSigningStringArrayEntitlement(_ key: String) -> [String] {
        #if os(macOS)
        guard let raw = codeSigningEntitlements()?[key] else { return [] }
        if let string = raw as? String, !string.isEmpty { return [string] }
        if let strings = raw as? [String] { return strings }
        if let array = raw as? NSArray {
            return array.compactMap { $0 as? String }
        }
        return []
        #else
        _ = key
        return []
        #endif
    }

    nonisolated private static func stringEntitlement(_ key: String) -> String? {
        #if os(macOS)
        let value = codeSigningEntitlements()?[key] as? String
        guard let value, !value.isEmpty else { return nil }
        return value
        #else
        _ = key
        return nil
        #endif
    }

    #if os(macOS)
    nonisolated private static func codeSigningEntitlements() -> NSDictionary? {
        codeSigningInformation()?[kSecCodeInfoEntitlementsDict] as? NSDictionary
    }

    nonisolated private static func codeSigningInformation() -> NSDictionary? {
        var dynamicCode: SecCode?
        guard SecCodeCopySelf([], &dynamicCode) == errSecSuccess, let dynamicCode else {
            return nil
        }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(dynamicCode, [], &staticCode) == errSecSuccess,
              let staticCode else {
            return nil
        }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &info
        ) == errSecSuccess else {
            return nil
        }
        return info as NSDictionary?
    }
    #endif
}
