import Foundation
import ReisenDiagnostics

public enum SelectionBatchDeleteHandlers {
    public struct RunResult: Equatable, Sendable {
        public let outcome: SelectionBatchDeletion.Outcome
        public let events: [DiagnosticEvent]

        public init(outcome: SelectionBatchDeletion.Outcome, events: [DiagnosticEvent]) {
            self.outcome = outcome
            self.events = events
        }
    }

    public static func deleteOpenBookings(
        ids: Set<UUID>,
        deleteOne: (UUID) throws -> Void
    ) -> RunResult {
        run(
            ids: ids,
            started: SelectionBatchDeleteDiagnostics.openBookingList(result: .started, count: ids.count)
        ) { count, errorType in
            if let errorType {
                SelectionBatchDeleteDiagnostics.openBookingList(
                    result: .failed,
                    count: count,
                    errorType: errorType
                )
            } else {
                SelectionBatchDeleteDiagnostics.openBookingList(result: .succeeded, count: count)
            }
        } deleteOne: { try deleteOne($0) }
    }

    public static func deleteTripBookings(
        ids: Set<UUID>,
        deleteOne: (UUID) throws -> Void
    ) -> RunResult {
        run(
            ids: ids,
            started: SelectionBatchDeleteDiagnostics.tripBookingList(result: .started, count: ids.count)
        ) { count, errorType in
            if let errorType {
                SelectionBatchDeleteDiagnostics.tripBookingList(
                    result: .failed,
                    count: count,
                    errorType: errorType
                )
            } else {
                SelectionBatchDeleteDiagnostics.tripBookingList(result: .succeeded, count: count)
            }
        } deleteOne: { try deleteOne($0) }
    }

    public static func deleteTrips(
        ids: Set<UUID>,
        deleteOne: (UUID) throws -> Void
    ) -> RunResult {
        run(
            ids: ids,
            started: SelectionBatchDeleteDiagnostics.tripList(result: .started, count: ids.count)
        ) { count, errorType in
            if let errorType {
                SelectionBatchDeleteDiagnostics.tripList(
                    result: .failed,
                    count: count,
                    errorType: errorType
                )
            } else {
                SelectionBatchDeleteDiagnostics.tripList(result: .succeeded, count: count)
            }
        } deleteOne: { try deleteOne($0) }
    }

    private static func run<ID: Hashable>(
        ids: Set<ID>,
        started: DiagnosticEvent,
        finish: (Int, String?) -> DiagnosticEvent,
        deleteOne: (ID) throws -> Void
    ) -> RunResult {
        // `started` vor dem Löschen erzeugen; Caller loggt die Event-Liste in Reihenfolge.
        var events = [started]
        let outcome = SelectionBatchDeletion.run(ids: ids, deleteOne: deleteOne)
        switch outcome {
        case .succeeded:
            events.append(finish(ids.count, nil))
        case .failed(_, _, let errorType):
            events.append(finish(ids.count, errorType))
        }
        return RunResult(outcome: outcome, events: events)
    }
}
