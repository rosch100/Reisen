import Foundation
import Testing
@testable import ReisenDomain

struct AppIconStyleTests {
    @Test func alternateIconName_standardIsNil_lightIsAppIconLight() {
        #expect(AppIconStyle.standard.alternateIconName == nil)
        #expect(AppIconStyle.light.alternateIconName == "AppIconLight")
    }

    @Test func fromStored_defaultsToStandard() {
        #expect(AppIconStyle.from(stored: nil) == .standard)
        #expect(AppIconStyle.from(stored: "bogus") == .standard)
        #expect(AppIconStyle.from(stored: "light") == .light)
    }

    @Test func settingsKey_isStable() {
        #expect(AppSettingsKeys.appIconStyle == "reisen_appIconStyle")
    }
}
