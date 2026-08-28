import Testing
import Foundation
@testable import ReisenCheck24

@Test("Check24BookingDetailURL: Hotel und Ferienwohnung")
func check24BookingDetailURLHotelStay() {
    #expect(Check24BookingDetailURL.isHotelStayDetail(
        URL(string: "https://hotel.check24.de/kundenbereich/buchung/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    ))
    #expect(Check24BookingDetailURL.isHotelStayDetail(
        URL(string: "https://hotel.check24.de/ul/kundenbereich/buchung/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    ))
    #expect(Check24BookingDetailURL.isHotelStayDetail(
        URL(string: "https://ferienwohnung.check24.de/kundenbereich/buchung/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
    ))
    #expect(!Check24BookingDetailURL.isHotelStayDetail(
        URL(string: "https://urlaub.check24.de/kundenbereich/detail/packagetest1")!
    ))
    #expect(!Check24BookingDetailURL.isHotelStayDetail(
        URL(string: "https://mietwagen.check24.de/ul/booking/list/foreign/testrental1")!
    ))
    #expect(!Check24BookingDetailURL.isHotelStayDetail(
        URL(string: "https://evil-hotel.check24.de/kundenbereich/buchung/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    ))
}

@Test("Check24BookingDetailURL: Flug und Fähre")
func check24BookingDetailURLFlightOrFerry() {
    #expect(Check24BookingDetailURL.isFlightOrFerryDetail(
        URL(string: "https://flug.check24.de/kundenbereich/buchung/TESTPNR")!
    ))
    #expect(Check24BookingDetailURL.isFlightOrFerryDetail(
        URL(string: "https://ferry.check24.de/kundenbereich/buchung/FERRY1")!
    ))
    #expect(!Check24BookingDetailURL.isFlightOrFerryDetail(
        URL(string: "https://flug.check24.de/kundenbereich/TESTPNR/Name")!
    ))
}

@Test("Check24BookingDetailURL: Mietwagen Detail vs Jumpin/Voucher")
func check24BookingDetailURLCarRental() {
    #expect(Check24BookingDetailURL.isCarRentalDetail(
        URL(string: "https://mietwagen.check24.de/ul/booking/list/foreign/testrental1")!
    ))
    #expect(Check24BookingDetailURL.isCarRentalDetail(
        URL(string: "https://mietwagen.check24.de/kb/testrental1")!
    ))
    #expect(!Check24BookingDetailURL.isCarRentalDetail(
        URL(string: "https://mietwagen.check24.de/ul/jumpin?source=account")!
    ))
    #expect(!Check24BookingDetailURL.isCarRentalDetail(
        URL(string: "https://mietwagen.check24.de/ajax/booking/document/abc/def/123")!
    ))
    #expect(!Check24BookingDetailURL.isCarRentalDetail(
        URL(string: "https://hotel.check24.de/kundenbereich/buchung/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    ))
    #expect(!Check24BookingDetailURL.isCarRentalDetail(
        URL(string: "https://not-mietwagen.check24.de/ul/booking/list/foreign/testrental1")!
    ))
    #expect(!Check24BookingDetailURL.isCarRentalDetail(
        URL(string: "https://mietwagen.check24.de/evil/ul/booking/list/foreign/testrental1")!
    ))
}

@Test("Check24BookingDetailURL: gleiche Mietwagen-Buchung trotz Redirect, kein Substring")
func check24BookingDetailURLSameCarRentalBooking() {
    let catalog = URL(string: "https://mietwagen.check24.de/ul/booking/list/foreign/test")!
    let short = URL(string: "https://mietwagen.check24.de/kb/test")!
    let other = URL(string: "https://mietwagen.check24.de/kb/testrental1")!
    #expect(Check24BookingDetailURL.isSameCarRentalBooking(catalog, short))
    #expect(Check24BookingDetailURL.isSameCarRentalBooking(short, catalog))
    #expect(!Check24BookingDetailURL.isSameCarRentalBooking(catalog, other))
    #expect(!Check24BookingDetailURL.isSameCarRentalBooking(
        catalog,
        URL(string: "https://mietwagen.check24.de/ul/jumpin?source=account")!
    ))
}
