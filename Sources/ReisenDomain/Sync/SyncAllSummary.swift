import Foundation

/// Zusammenfassung nach sequentiellem Sync mehrerer Provider.
public enum SyncAllSummary {
    public static func statusLine(successCount: Int, failureCount: Int) -> String {
        "Sync beendet: \(successCount) ok, \(failureCount) fehlgeschlagen."
    }

    public static func errorDetails(failures: [(providerName: String, message: String)]) -> String {
        failures
            .map { "\($0.providerName): \($0.message)" }
            .joined(separator: "\n")
    }
}
