import Foundation

public enum CancellationDeadlineFutureSort {
    public static func futureSorted(
        _ deadlines: [CancellationDeadline],
        now: Date
    ) -> [CancellationDeadline] {
        deadlines
            .filter { $0.deadlineAt > now }
            .sorted(by: { $0.deadlineAt < $1.deadlineAt })
    }
}
