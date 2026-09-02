import Foundation
import Testing
@testable import ReisenAppCore

struct SelectionBatchDeletionTests {
    private struct Boom: Error, LocalizedError {
        var errorDescription: String? { "boom" }
    }

    @Test func runSucceedsInSortedOrder() {
        var deleted: [String] = []
        let outcome = SelectionBatchDeletion.run(ids: ["c", "a", "b"]) { id in
            deleted.append(id)
        }
        #expect(outcome == .succeeded)
        #expect(deleted == ["a", "b", "c"])
    }

    @Test func runFailStopDoesNotContinue() {
        var deleted: [String] = []
        let outcome = SelectionBatchDeletion.run(ids: ["a", "b", "c"]) { id in
            if id == "b" { throw Boom() }
            deleted.append(id)
        }
        #expect(outcome == .failed(index: 1, errorDescription: "boom", errorType: "Boom"))
        #expect(deleted == ["a"])
    }

    @Test func remainingIDsEmptyOnSuccess() {
        let outcome = SelectionBatchDeletion.run(ids: ["b", "a"]) { _ in }
        #expect(SelectionBatchDeletion.remainingIDs(from: ["b", "a"], outcome: outcome).isEmpty)
    }

    @Test func remainingIDsIncludesFailedIndexAndLater() {
        let ids: Set<String> = ["c", "a", "b"]
        let outcome = SelectionBatchDeletion.run(ids: ids) { id in
            if id == "b" { throw Boom() }
        }
        #expect(outcome == .failed(index: 1, errorDescription: "boom", errorType: "Boom"))
        #expect(SelectionBatchDeletion.remainingIDs(from: ids, outcome: outcome) == ["b", "c"])
    }
}

struct SelectionBatchDeleteHandlersTests {
    private struct Boom: Error {}

    @Test func openBookingsHandlerEmitsStartedAndSucceeded() {
        let result = SelectionBatchDeleteHandlers.deleteOpenBookings(ids: [UUID(), UUID()]) { _ in }
        #expect(result.outcome == .succeeded)
        #expect(result.events.count == 2)
        #expect(result.events[0].result == .started)
        #expect(result.events[0].event == "delete_batch")
        #expect(result.events[0].component == "OpenBookingList")
        #expect(result.events[1].result == .succeeded)
    }

    @Test func openBookingsHandlerEmitsFailedOnError() {
        let result = SelectionBatchDeleteHandlers.deleteOpenBookings(ids: [UUID()]) { _ in
            throw Boom()
        }
        guard case .failed = result.outcome else {
            Issue.record("expected failed")
            return
        }
        #expect(result.events.last?.result == .failed)
    }
}

struct SelectionBatchDeleteDiagnosticsTests {
    @Test func deleteBatchReasonContainsCount() {
        let event = SelectionBatchDeleteDiagnostics.tripList(result: .started, count: 4)
        #expect(event.component == "TripList")
        #expect(event.phase == "selection_action")
        #expect(event.event == "delete_batch")
        #expect(event.reason == "count=4")
    }
}
