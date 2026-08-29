import Foundation
import Testing
import ReisenAppCore

@Test @MainActor
func pasteImportReviewQueue_secondAdvanceWhilePendingIsIgnored() async {
    let queue = PasteImportReviewQueue()
    var presentations = 0
    queue.advance(ifPending: true) {
        presentations += 1
    }
    queue.advance(ifPending: true) {
        presentations += 1
    }
    await Task.yield()
    await Task.yield()
    #expect(presentations == 1)
}

@Test @MainActor
func pasteImportReviewQueue_skipsWhenNothingPending() async {
    let queue = PasteImportReviewQueue()
    var presentations = 0
    queue.advance(ifPending: false) {
        presentations += 1
    }
    await Task.yield()
    #expect(presentations == 0)
}
