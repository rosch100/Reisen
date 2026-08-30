import Testing
import Foundation
@testable import ReisenDomain

@Test func bookingPortalCancelTitle_keysResolveInCatalog() {
    for key in [
        L10nKey.actionOpenShort,
        .actionCancelInPortal,
        .actionCancelInPortalMenu,
        .actionCancelInPortalHelp,
        .actionCopyCancellationLink,
    ] {
        let value = L10n.string(key)
        #expect(!value.isEmpty, "Key \(key.rawValue) leer")
        #expect(value != key.rawValue, "Key \(key.rawValue) nicht lokalisiert")
    }
    #expect(BookingPortalCancelTitle.button != L10nKey.actionCancelInPortal.rawValue)
    #expect(BookingPortalCancelTitle.menu != L10nKey.actionCancelInPortalMenu.rawValue)
    #expect(!BookingPortalCancelTitle.help.isEmpty)
}

@Test func bookingPortalOpenTitle_shortKeyResolves() {
    #expect(BookingPortalOpenTitle.short != L10nKey.actionOpenShort.rawValue)
    #expect(!BookingPortalOpenTitle.short.isEmpty)
}
