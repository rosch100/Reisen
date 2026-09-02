import Foundation

public enum SelectionBatchDeletion {
    public enum Outcome: Equatable, Sendable {
        case succeeded
        case failed(index: Int, errorDescription: String, errorType: String)
    }

    /// Deletes IDs in ascending `String(describing:)` order. Fail-stop on first error.
    public static func run<ID: Hashable>(
        ids: Set<ID>,
        deleteOne: (ID) throws -> Void
    ) -> Outcome {
        let ordered = orderedIDs(ids)
        for (index, id) in ordered.enumerated() {
            do {
                try deleteOne(id)
            } catch {
                return .failed(
                    index: index,
                    errorDescription: error.localizedDescription,
                    errorType: String(describing: type(of: error))
                )
            }
        }
        return .succeeded
    }

    /// IDs still present after a fail-stop run (failed index inclusive). Empty on success.
    public static func remainingIDs<ID: Hashable>(
        from ids: Set<ID>,
        outcome: Outcome
    ) -> Set<ID> {
        switch outcome {
        case .succeeded:
            return []
        case .failed(let index, _, _):
            return Set(orderedIDs(ids).dropFirst(index))
        }
    }

    private static func orderedIDs<ID: Hashable>(_ ids: Set<ID>) -> [ID] {
        ids.sorted { String(describing: $0) < String(describing: $1) }
    }
}
