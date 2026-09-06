import Testing
import Foundation
@testable import ReisenCheck24
import ReisenProviders

@Test func hotelNavigationTimeout_doesNotAbortCatalog() {
    let timeout = NavigationSettleTimeout.error(
        for: URL(string: "https://hotel.check24.de/kundenbereich/buchung/abc")!
    )
    #expect(Check24HotelEnrichIsolation.shouldRethrow(timeout) == false)
}

@Test func hotelEnrichCancellation_abortsCatalog() {
    #expect(Check24HotelEnrichIsolation.shouldRethrow(CancellationError()) == true)
}

@Test func hotelEnrichUnknownError_abortsCatalog() {
    let error = NSError(domain: "TestDomain", code: 9)
    #expect(Check24HotelEnrichIsolation.shouldRethrow(error) == true)
}
