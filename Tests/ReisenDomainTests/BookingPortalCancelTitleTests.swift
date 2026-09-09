import Testing
import Foundation
@testable import ReisenDomain

@Suite(.serialized)
struct BookingPortalCancelTitleTests {
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

@Test func bookingPortalCancelTitle_buttonNamesPortalNavigationInGerman() {
    L10n.withLocale(Locale(identifier: "de")) {
        #expect(L10n.string(.actionCancelInPortal) == "Stornieren im Portal…")
        #expect(BookingPortalCancelTitle.button == "Stornieren im Portal…")
        #expect(BookingPortalCancelTitle.button.contains("Portal"))
        #expect(BookingPortalCancelTitle.button.hasSuffix("…"))
    }
}

@Test func bookingPortalCancelTitle_buttonNamesPortalNavigationInEnglish() {
    L10n.withLocale(Locale(identifier: "en")) {
        #expect(L10n.string(.actionCancelInPortal) == "Cancel in Portal…")
        #expect(BookingPortalCancelTitle.button == "Cancel in Portal…")
        #expect(BookingPortalCancelTitle.button.hasSuffix("…"))
    }
}

@Test func bookingPortalCancelLoadFailed_keyResolves() {
    L10n.withLocale(Locale(identifier: "de")) {
        let value = L10n.string(.bookingPortalCancelLoadFailed)
        #expect(value != L10nKey.bookingPortalCancelLoadFailed.rawValue)
        #expect(!value.isEmpty)
        #expect(value == "Die Stornoseite konnte nicht geladen werden.")
    }
}
}
