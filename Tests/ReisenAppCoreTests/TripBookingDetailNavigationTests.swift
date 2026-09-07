import Foundation
import Testing
import ReisenAppCore

@Suite("TripBookingDetailNavigation")
struct TripBookingDetailNavigationTests {
    @Test("User tip sets presented booking id for item destination")
    func applyUserSelectSetsPresentedID() {
        var presented: UUID?
        let id = UUID()
        TripBookingDetailNavigation.applyUserSelect(bookingID: id, presentedBookingID: &presented)
        #expect(presented == id)
    }
}
