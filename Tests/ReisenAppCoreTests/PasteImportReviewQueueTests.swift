import Foundation
import Testing
import ReisenAppCore

@Test @MainActor
func pasteImportReviewQueue_secondAdvanceWhilePendingIsIgnored() async {
    let queue = PasteImportReviewQueue()
    var presentations = 0
    let first = queue.advance(ifPending: true) {
        presentations += 1
    }
    let second = queue.advance(ifPending: true) {
        presentations += 1
    }
    #expect(second == nil)
    await first?.value
    #expect(presentations == 1)
}

@Test @MainActor
func pasteImportReviewQueue_skipsWhenNothingPending() async {
    let queue = PasteImportReviewQueue()
    var presentations = 0
    let task = queue.advance(ifPending: false) {
        presentations += 1
    }
    #expect(task == nil)
    #expect(presentations == 0)
}
