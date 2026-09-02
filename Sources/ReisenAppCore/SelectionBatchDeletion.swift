import Foundation

public enum SelectionBatchDeletion {
    public enum Outcome: Equatable, Sendable {
        case succeeded
        case failed(index: Int, errorDescription: String)
    }

    /// Deletes IDs in ascending `String(describing:)` order. Fail-stop on first error.
    public static func run<ID: Hashable>(
        ids: Set<ID>,
        deleteOne: (ID) throws -> Void
    ) -> Outcome {
        let ordered = ids.sorted { String(describing: $0) < String(describing: $1) }
        for (index, id) in ordered.enumerated() {
            do {
                try deleteOne(id)
            } catch {
                return .failed(index: index, errorDescription: error.localizedDescription)
            }
        }
        return .succeeded
    }
}
