import Foundation

protocol EventKitBatchCommitting: AnyObject {
    func saveItem(id: String, commit: Bool) throws
    func commit() throws
}

enum EventKitDeadlineBatchCommit {
    static func run(itemIDs: [String], store: EventKitBatchCommitting) throws {
        guard !itemIDs.isEmpty else { return }
        for id in itemIDs {
            try store.saveItem(id: id, commit: false)
        }
        try store.commit()
    }
}
