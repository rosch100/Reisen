import Testing
import Foundation
import ReisenAppCore
import ReisenDomain

@Test func uiTestingLaunch_detectsPopulatedAndEmptyFlags() {
    #expect(UITestingLaunch.argument == "-UITesting")
    #expect(UITestingLaunch.emptyArgument == "-UITestingEmpty")
    #expect(UITestingLaunch.pasteImportArgument == "-UITestingPasteImport")
    #expect(UITestingLaunch.isActive(arguments: ["-UITesting"]))
    #expect(UITestingLaunch.shouldSeed(arguments: ["-UITesting"]))
    #expect(UITestingLaunch.isActive(arguments: ["-UITestingEmpty"]))
    #expect(!UITestingLaunch.shouldSeed(arguments: ["-UITestingEmpty"]))
    #expect(!UITestingLaunch.isActive(arguments: []))
    #expect(UITestingLaunch.shouldInjectPasteImportFixture(arguments: [
        UITestingLaunch.argument,
        UITestingLaunch.pasteImportArgument,
    ]))
    #expect(!UITestingLaunch.shouldInjectPasteImportFixture(arguments: [
        UITestingLaunch.pasteImportArgument,
    ]))
    #expect(UITestingMode.from(arguments: ["-UITesting"]) == .populated)
    #expect(UITestingMode.from(arguments: ["-UITestingEmpty"]) == .empty)
    #expect(UITestingMode.from(arguments: []).skipsSideEffects == false)
    #expect(
        UITestingMode.from(arguments: [], environment: [UITestingLaunch.environmentKey: UITestingLaunch.environmentPopulated])
            == .populated
    )
    #expect(
        UITestingMode.from(arguments: [], environment: [UITestingLaunch.environmentKey: UITestingLaunch.environmentEmpty])
            == .empty
    )
}

@Test func uiTestingLaunch_isolatedSuiteIsNotStandard() {
    let suite = "ReisenTests.uiTesting.defaults"
    let defaults = UITestingLaunch.makeIsolatedDefaults(suiteName: suite)
    #expect(defaults !== UserDefaults.standard)
    defaults.set(true, forKey: "probe")
    let wiped = UITestingLaunch.makeIsolatedDefaults(suiteName: suite)
    #expect(wiped.object(forKey: "probe") == nil)
}

@Test func uiTestingLaunch_seedProviderEnablementOnlyForPopulated() {
    let suite = "ReisenTests.uiTesting.providerEnable.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suite) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suite) }

    UITestingLaunch.seedProviderEnablementIfNeeded(
        mode: .empty,
        defaults: defaults,
        syncProviderIDs: [.check24]
    )
    #expect(!AppSettingsKeys.isProviderEnabled(.check24, defaults: defaults))

    UITestingLaunch.seedProviderEnablementIfNeeded(
        mode: .populated,
        defaults: defaults,
        syncProviderIDs: [.check24]
    )
    #expect(AppSettingsKeys.isProviderEnabled(.check24, defaults: defaults))
}

@Test func uiTestingLaunch_seedProviderSetupMarksCompletedForPopulated() {
    let suite = "ReisenTests.uiTesting.providerSetup.populated.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suite) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suite) }

    #expect(ProviderFirstLaunchSetup.shouldPresent(defaults: defaults))

    UITestingLaunch.seedProviderSetupIfNeeded(mode: .populated, defaults: defaults)

    #expect(defaults.bool(forKey: AppSettingsKeys.providerSetupCompleted))
    #expect(ProviderFirstLaunchSetup.isInitialSetupHidden(defaults: defaults))
    #expect(!ProviderFirstLaunchSetup.shouldPresent(defaults: defaults))
}

@Test func uiTestingLaunch_seedProviderSetupDoesNotMarkForEmpty() {
    let suite = "ReisenTests.uiTesting.providerSetup.empty.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suite) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suite) }

    UITestingLaunch.seedProviderSetupIfNeeded(mode: .empty, defaults: defaults)

    #expect(!defaults.bool(forKey: AppSettingsKeys.providerSetupCompleted))
    #expect(ProviderFirstLaunchSetup.shouldPresent(defaults: defaults))
}
