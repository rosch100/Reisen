import Foundation

/// Lauf-Lifecycle gegen Cancel-/Fail-Races: nur der aktuelle `runID` darf die Phase setzen.
///
/// Die schwere Arbeit (`work`) läuft **nicht** auf dem Main Actor. Abschluss-Callbacks schon.
@MainActor
public final class PasteImportRunLifetime {
    private var runID = UUID()
    private var task: Task<Void, Never>?

    public init() {}

    /// Startet einen Lauf: `work` off-Main, Erfolg/Fehler auf Main.
    public func begin<Success: Sendable>(
        work: @escaping @Sendable () async throws -> Success,
        onSuccess: @escaping @MainActor (Success) -> Void,
        onFailure: @escaping @MainActor (Error) -> Void
    ) {
        invalidate()
        let id = UUID()
        runID = id
        task = Task { [weak self] in
            let outcome: Result<Success, Error>
            do {
                outcome = .success(try await work())
            } catch {
                outcome = .failure(error)
            }
            await MainActor.run {
                guard let self, self.runID == id else { return }
                self.task = nil
                switch outcome {
                case .success(let value):
                    onSuccess(value)
                case .failure(let error):
                    onFailure(error)
                }
            }
        }
    }

    /// Invalidiert den laufenden Lauf (Cancel, Reset, Fail).
    public func invalidate() {
        runID = UUID()
        task?.cancel()
        task = nil
    }
}
