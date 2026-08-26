import Testing
import Foundation
import ReisenDomain

@Test func providerEnabledKey_isStableAndPrefixed() {
    #expect(
        AppSettingsKeys.providerEnabledKey(for: .check24)
            == "reisen_providerEnabled_check24"
    )
    #expect(
        AppSettingsKeys.providerEnabledKey(for: .opodo)
            == "reisen_providerEnabled_opodo"
    )
    #expect(
        AppSettingsKeys.providerEnabledKey(for: .booking)
            == "reisen_providerEnabled_booking"
    )
}

@Test func preferredKeychainAccountKey_isStableAndPrefixed() {
    #expect(
        AppSettingsKeys.preferredKeychainAccountKey(for: .booking)
            == "reisen_preferredKeychainAccount_booking"
    )
    #expect(
        AppSettingsKeys.preferredKeychainAccountKey(for: .opodo)
            == "reisen_preferredKeychainAccount_opodo"
    )
}

@Test func rememberLoginAutomaticallyKey_isStableAndPrefixed() {
    #expect(
        AppSettingsKeys.rememberLoginAutomatically == "reisen_rememberLoginAutomatically"
    )
}

@Test func rememberLoginAutomatically_defaultsToFalseWhenUnset() {
    let defaults = UserDefaults(suiteName: "ReisenTests.rememberLogin")!
    defaults.removePersistentDomain(forName: "ReisenTests.rememberLogin")
    #expect(!AppSettingsKeys.isRememberLoginAutomatically(defaults: defaults))
    defaults.set(true, forKey: AppSettingsKeys.rememberLoginAutomatically)
    #expect(AppSettingsKeys.isRememberLoginAutomatically(defaults: defaults))
}

@Test func reportErrorsToGitHub_defaultsToFalseWhenUnset() {
    let suite = "ReisenTests.reportErrorsToGitHub"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    #expect(AppSettingsKeys.reportErrorsToGitHub == "reisen_reportErrorsToGitHub")
    #expect(AppSettingsKeys.isReportErrorsToGitHub(defaults: defaults) == false)
    defaults.set(true, forKey: AppSettingsKeys.reportErrorsToGitHub)
    #expect(AppSettingsKeys.isReportErrorsToGitHub(defaults: defaults))
}

@Test func tripDetailSplitKeys_areStableAndPrefixed() {
    #expect(AppSettingsKeys.tripDetailPanelVisible == "reisen_tripDetailPanelVisible")
    #expect(AppSettingsKeys.tripDetailPanelHeight == "reisen_tripDetailPanelHeight")
    #expect(AppSettingsKeys.sidebarColumnWidth == "reisen_sidebarColumnWidth")
    #expect(AppSettingsKeys.bookingListColumnWidth == "reisen_bookingListColumnWidth")
}

