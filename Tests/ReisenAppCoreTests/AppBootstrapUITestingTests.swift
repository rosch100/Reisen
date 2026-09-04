import Testing
import Foundation
import SwiftData
import ReisenAppCore
import ReisenData
import ReisenDomain

@MainActor
@Test func appBootstrap_uiTestingPopulatedUsesInMemorySeed() throws {
    let state = try AppBootstrap.makeReadyState(registry: .empty, uiTesting: .populated)
    guard case .ready(let container, _, _, _) = state else {
        Issue.record("expected ready state")
        return
    }

    let trips = try container.mainContext.fetch(FetchDescriptor<SDTrip>())
    #expect(trips.contains { $0.id == UITestingSeed.tripID })
}

@MainActor
@Test func appBootstrap_uiTestingEmptyHasNoSeed() throws {
    let state = try AppBootstrap.makeReadyState(registry: .empty, uiTesting: .empty)
    guard case .ready(let container, _, _, _) = state else {
        Issue.record("expected ready state")
        return
    }

    let trips = try container.mainContext.fetch(FetchDescriptor<SDTrip>())
    #expect(trips.isEmpty)
}

@MainActor
@Test func appBootstrap_populatedSeedsProviderSetupCompleted() throws {
    let defaults = UITestingLaunch.isolatedDefaults
    defaults.removeObject(forKey: AppSettingsKeys.providerSetupCompleted)
    defaults.removeObject(forKey: AppSettingsKeys.providerSetupDeferred)
    defer { AppSettingsDefaults.installOverride(nil) }

    _ = try AppBootstrap.makeReadyState(registry: .empty, uiTesting: .populated)

    #expect(defaults.bool(forKey: AppSettingsKeys.providerSetupCompleted))
    #expect(!ProviderFirstLaunchSetup.shouldPresent(defaults: defaults))
}

/// Empty skips `seedProviderSetup`; existing `providerEnabled_*` must still complete via bootstrap hook.
@MainActor
@Test func appBootstrap_marksSetupCompletedWhenExistingProviderKey() throws {
    let defaults = UITestingLaunch.isolatedDefaults
    defaults.removeObject(forKey: AppSettingsKeys.providerSetupCompleted)
    defaults.removeObject(forKey: AppSettingsKeys.providerSetupDeferred)
    defaults.set(false, forKey: AppSettingsKeys.providerEnabledKey(for: .check24))
    defaults.set(true, forKey: ProviderEnabledDefaultsMigration.migratedKey)
    defer { AppSettingsDefaults.installOverride(nil) }

    _ = try AppBootstrap.makeReadyState(registry: .empty, uiTesting: .empty)

    #expect(defaults.bool(forKey: AppSettingsKeys.providerSetupCompleted))
    #expect(!ProviderFirstLaunchSetup.shouldPresent(defaults: defaults))
}
