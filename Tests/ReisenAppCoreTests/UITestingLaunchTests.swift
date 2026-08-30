import Testing
import Foundation
import ReisenAppCore

@Test func uiTestingLaunch_detectsPopulatedAndEmptyFlags() {
    #expect(UITestingLaunch.argument == "-UITesting")
    #expect(UITestingLaunch.emptyArgument == "-UITestingEmpty")
    #expect(UITestingLaunch.isActive(arguments: ["-UITesting"]))
    #expect(UITestingLaunch.shouldSeed(arguments: ["-UITesting"]))
    #expect(UITestingLaunch.isActive(arguments: ["-UITestingEmpty"]))
    #expect(!UITestingLaunch.shouldSeed(arguments: ["-UITestingEmpty"]))
    #expect(!UITestingLaunch.isActive(arguments: []))
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
