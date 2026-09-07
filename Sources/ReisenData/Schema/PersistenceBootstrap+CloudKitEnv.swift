import Foundation
#if os(macOS)
import Security
#endif

extension PersistenceBootstrap {
    /// Effective CloudKit: Env/Entitlements **and** caller-supplied user preference.
    /// Resolve `AppSettingsKeys.isICloudSyncEnabled()` outside ReisenData and pass it in.
    nonisolated public static func isCloudKitEnabledByEnvironment(
        iCloudSyncPreferenceEnabled: Bool
    ) -> Bool {
        #if os(macOS)
        let snap = cachedCodeSigningSnapshot
        return isCloudKitEnabled(
            environment: ProcessInfo.processInfo.environment,
            processName: ProcessInfo.processInfo.processName,
            arguments: CommandLine.arguments,
            teamIdentifier: snap.teamIdentifier,
            applicationIdentifier: snap.applicationIdentifier,
            icloudContainerIdentifiers: snap.icloudContainerIdentifiers,
            icloudServices: snap.icloudServices,
            icloudContainerEnvironment: snap.icloudContainerEnvironment,
            iCloudSyncPreferenceEnabled: iCloudSyncPreferenceEnabled
        )
        #else
        return isCloudKitEnabled(
            environment: ProcessInfo.processInfo.environment,
            processName: ProcessInfo.processInfo.processName,
            arguments: CommandLine.arguments,
            teamIdentifier: nil,
            applicationIdentifier: nil,
            icloudContainerIdentifiers: [],
            icloudServices: [],
            icloudContainerEnvironment: nil,
            iCloudSyncPreferenceEnabled: iCloudSyncPreferenceEnabled
        )
        #endif
    }

    /// Env/Entitlements only — ignores the user iCloud-sync preference.
    nonisolated public static func isCloudKitAllowedByEnvironmentProcess() -> Bool {
        #if os(macOS)
        let snap = cachedCodeSigningSnapshot
        return isCloudKitAllowedByEnvironment(
            environment: ProcessInfo.processInfo.environment,
            processName: ProcessInfo.processInfo.processName,
            arguments: CommandLine.arguments,
            teamIdentifier: snap.teamIdentifier,
            applicationIdentifier: snap.applicationIdentifier,
            icloudContainerIdentifiers: snap.icloudContainerIdentifiers,
            icloudServices: snap.icloudServices,
            icloudContainerEnvironment: snap.icloudContainerEnvironment
        )
        #else
        return isCloudKitAllowedByEnvironment(
            environment: ProcessInfo.processInfo.environment,
            processName: ProcessInfo.processInfo.processName,
            arguments: CommandLine.arguments,
            teamIdentifier: nil,
            applicationIdentifier: nil,
            icloudContainerIdentifiers: [],
            icloudServices: [],
            icloudContainerEnvironment: nil
        )
        #endif
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
        cachedCodeSigningSnapshot.teamIdentifier
        #else
        return nil
        #endif
    }

    nonisolated static func codeSigningApplicationIdentifier() -> String? {
        #if os(macOS)
        cachedCodeSigningSnapshot.applicationIdentifier
        #else
        return nil
        #endif
    }

    #if os(macOS)
    /// Process-lifetime cache: entitlements/signing do not change after launch.
    /// Spins 2026-09-04: every prefs remote-change re-entered `SecCodeCopySigningInformation` on MainActor.
    nonisolated private static let cachedCodeSigningSnapshot = CodeSigningSnapshot.load()

    private struct CodeSigningSnapshot: Sendable {
        let teamIdentifier: String?
        let applicationIdentifier: String?
        let icloudContainerIdentifiers: [String]
        let icloudServices: [String]
        let icloudContainerEnvironment: String?

        nonisolated static func load() -> CodeSigningSnapshot {
            let info = loadCodeSigningInformation()
            let entitlements = info?[kSecCodeInfoEntitlementsDict] as? NSDictionary
            let team = info?[kSecCodeInfoTeamIdentifier] as? String
            return CodeSigningSnapshot(
                teamIdentifier: (team?.isEmpty == false) ? team : nil,
                applicationIdentifier: stringEntitlement(
                    "com.apple.application-identifier",
                    entitlements: entitlements
                ),
                icloudContainerIdentifiers: stringArrayEntitlement(
                    "com.apple.developer.icloud-container-identifiers",
                    entitlements: entitlements
                ),
                icloudServices: stringArrayEntitlement(
                    "com.apple.developer.icloud-services",
                    entitlements: entitlements
                ),
                icloudContainerEnvironment: stringEntitlement(
                    "com.apple.developer.icloud-container-environment",
                    entitlements: entitlements
                )
            )
        }
    }

    nonisolated private static func stringArrayEntitlement(
        _ key: String,
        entitlements: NSDictionary?
    ) -> [String] {
        guard let raw = entitlements?[key] else { return [] }
        if let string = raw as? String, !string.isEmpty { return [string] }
        if let strings = raw as? [String] { return strings }
        if let array = raw as? NSArray {
            return array.compactMap { $0 as? String }
        }
        return []
    }

    nonisolated private static func stringEntitlement(
        _ key: String,
        entitlements: NSDictionary?
    ) -> String? {
        let value = entitlements?[key] as? String
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    nonisolated private static func loadCodeSigningInformation() -> NSDictionary? {
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
