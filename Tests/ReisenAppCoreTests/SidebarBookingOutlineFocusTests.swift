import Foundation
import Testing
@testable import ReisenAppCore

struct SidebarBookingOutlineFocusTests {
    @Test func selectCurrentReturnsSingletonSelection() {
        let id = UUID()
        let result = SidebarBookingOutlineFocus.select(mailbox: .current, bookingID: id)
        #expect(result.mailbox == .current)
        #expect(result.selectedIDs == [id])
    }

    @Test func selectElapsedReturnsSingletonSelection() {
        let id = UUID()
        let result = SidebarBookingOutlineFocus.select(mailbox: .elapsed, bookingID: id)
        #expect(result.mailbox == .elapsed)
        #expect(result.selectedIDs == [id])
    }
}
