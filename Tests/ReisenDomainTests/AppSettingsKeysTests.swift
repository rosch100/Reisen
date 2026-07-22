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

@Test func tripDetailSplitKeys_areStableAndPrefixed() {
    #expect(AppSettingsKeys.tripDetailPanelVisible == "reisen_tripDetailPanelVisible")
    #expect(AppSettingsKeys.tripDetailPanelHeight == "reisen_tripDetailPanelHeight")
    #expect(AppSettingsKeys.sidebarColumnWidth == "reisen_sidebarColumnWidth")
    #expect(AppSettingsKeys.bookingListColumnWidth == "reisen_bookingListColumnWidth")
}

