import Foundation
import Testing
import ReisenSharedUI

@Suite
struct TimelineSelectionTests {
    @Test func primaryID_empty_isNil() {
        #expect(TimelineSelection.primaryID(in: []) == nil)
    }

    @Test func primaryID_single_returnsThatID() {
        #expect(TimelineSelection.primaryID(in: ["a"]) == "a")
    }

    @Test func primaryID_multiple_isNil() {
        #expect(TimelineSelection.primaryID(in: ["a", "b"]) == nil)
    }
}
