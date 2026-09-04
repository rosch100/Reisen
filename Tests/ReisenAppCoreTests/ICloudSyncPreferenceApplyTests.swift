import Foundation
import Testing
import ReisenAppCore
import ReisenDomain

@Suite(.serialized)
struct ICloudSyncPreferenceApplyTests {
    @MainActor
    @Test func keepLocal_setsPreferenceOff() async throws {
        let defaults = UITestingLaunch.isolatedDefaults
        AppSettingsKeys.setICloudSyncEnabled(true, defaults: defaults)
        defer {
            defaults.removeObject(forKey: AppSettingsKeys.icloudSyncEnabled)
            AppSettingsDefaults.installOverride(nil)
        }

        let bootstrap = AppBootstrap(
            registry: .empty,
            uiTesting: .empty,
            crashCatcherInstall: {},
            crashCatcherFlush: {}
        )
        await bootstrap.applyICloudSyncPreference(enabled: false, wipeCloud: false)

        #expect(AppSettingsKeys.isICloudSyncEnabled(defaults: defaults) == false)
        guard case .ready = bootstrap.state else {
            Issue.record("expected ready after keep-local disable; got \(String(describing: bootstrap.state))")
            return
        }
    }

    @MainActor
    @Test func enable_setsPreferenceOn() async throws {
        let defaults = UITestingLaunch.isolatedDefaults
        AppSettingsKeys.setICloudSyncEnabled(false, defaults: defaults)
        defer {
            defaults.removeObject(forKey: AppSettingsKeys.icloudSyncEnabled)
            AppSettingsDefaults.installOverride(nil)
        }

        let bootstrap = AppBootstrap(
            registry: .empty,
            uiTesting: .empty,
            crashCatcherInstall: {},
            crashCatcherFlush: {}
        )
        await bootstrap.applyICloudSyncPreference(enabled: true, wipeCloud: false)

        #expect(AppSettingsKeys.isICloudSyncEnabled(defaults: defaults) == true)
        guard case .ready = bootstrap.state else {
            Issue.record("expected ready after enable; got \(String(describing: bootstrap.state))")
            return
        }
    }
}
