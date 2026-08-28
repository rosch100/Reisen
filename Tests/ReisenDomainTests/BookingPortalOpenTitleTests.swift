import Testing
import Foundation
@testable import ReisenDomain

@Test func bookingPortalOpenTitle_distinguishesAppAndNeutral() {
    let withApp = BookingPortalOpenTitle.openBooking(
        providerID: .booking,
        isNativeAppInstalled: true
    )
    let withoutApp = BookingPortalOpenTitle.openBooking(
        providerID: .booking,
        isNativeAppInstalled: false
    )
    #expect(withApp != withoutApp)
    #expect(withApp.contains("Booking.com"))
    #expect(!withoutApp.isEmpty)
    #expect(withoutApp != L10nKey.actionOpenBooking.rawValue)
    #expect(!BookingPortalOpenTitle.openInBrowser.isEmpty)
    #expect(BookingPortalOpenTitle.openInBrowser != L10nKey.actionOpenInBrowser.rawValue)
    #expect(!BookingPortalOpenTitle.openInBrowserHelp.isEmpty)
}

@Test func bookingPortalOpenTitle_keysResolveInCatalog() {
    for key in [
        L10nKey.actionOpenBooking,
        .actionOpenInBrowser,
        .actionOpenInBrowserHelp,
        .actionOpenInProviderApp,
        .gapSearchHotel,
        .gapSearchFlight,
        .gapSearchMenu,
        .gapSearchAllEnabled,
        .gapSearchProviderPicker,
    ] {
        let value = L10n.string(key)
        #expect(!value.isEmpty, "Key \(key.rawValue) leer")
        #expect(value != key.rawValue, "Key \(key.rawValue) nicht lokalisiert")
    }
    #expect(L10n.format(.actionOpenInProviderApp, "Booking.com").contains("Booking.com"))
}
