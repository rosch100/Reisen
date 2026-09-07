import Testing
@testable import ReisenAppCore

@Suite("EventKitDeadlineBatchCommit")
struct EventKitDeadlineBatchCommitTests {
    final class FakeStore: EventKitBatchCommitting {
        var saveCalls: [(id: String, commit: Bool)] = []
        var commitCount = 0

        func saveItem(id: String, commit: Bool) throws {
            saveCalls.append((id, commit))
        }

        func commit() throws {
            commitCount += 1
        }
    }

    @Test func run_savesWithoutCommitThenSingleCommit() throws {
        let store = FakeStore()
        try EventKitDeadlineBatchCommit.run(itemIDs: ["a", "b", "c"], store: store)
        #expect(store.saveCalls.map(\.commit) == [false, false, false])
        #expect(store.saveCalls.map(\.id) == ["a", "b", "c"])
        #expect(store.commitCount == 1)
    }

    @Test func run_empty_doesNotCommit() throws {
        let store = FakeStore()
        try EventKitDeadlineBatchCommit.run(itemIDs: [], store: store)
        #expect(store.saveCalls.isEmpty)
        #expect(store.commitCount == 0)
    }
}
