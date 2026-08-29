import Foundation

/// Lauf-Lifecycle gegen Cancel-/Fail-Races: nur der aktuelle `runID` darf die Phase setzen.
@MainActor
public final class PasteImportRunLifetime {
    private var runID = UUID()
    private var task: Task<Void, Never>?

    public init() {}

    /// Startet einen Lauf und liefert dessen ID an den Body.
    public func begin(_ body: @escaping @MainActor (_ runID: UUID) async -> Void) {
        invalidate()
        let id = UUID()
        runID = id
        task = Task { @MainActor in
            await body(id)
        }
    }

    /// Wendet das Ergebnis nur an, wenn `id` noch der aktuelle Lauf ist.
    public func complete(ifCurrent id: UUID, _ apply: () -> Void) {
        guard runID == id else { return }
        task = nil
        apply()
    }

    /// Invalidiert den laufenden Lauf (Cancel, Reset, Fail).
    public func invalidate() {
        runID = UUID()
        task?.cancel()
        task = nil
    }
}
