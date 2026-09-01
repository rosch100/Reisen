import Foundation
import Testing
@testable import ReisenAppCore

struct SidebarOpenSectionOutlineTests {
    @Test func collapsedHidesBookingRows() {
        let ids = [UUID(), UUID()]
        #expect(SidebarOpenSectionOutline.visibleBookingIDs(from: ids, isExpanded: false).isEmpty)
    }

    @Test func expandedShowsBookingRowsInOrder() {
        let ids = [UUID(), UUID()]
        #expect(SidebarOpenSectionOutline.visibleBookingIDs(from: ids, isExpanded: true) == ids)
    }
}
