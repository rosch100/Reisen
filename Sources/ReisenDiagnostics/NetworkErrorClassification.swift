import Foundation

/// SSOT für Timeout-/Cancel-Klassifikation in Session-Probes und Diagnose.
public enum NetworkErrorClassification {
    public static var isCurrentTaskCancelled: Bool {
        Task.isCancelled
    }

    public static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || isCurrentTaskCancelled
    }

    public static func isURLTimeout(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut
    }
}
