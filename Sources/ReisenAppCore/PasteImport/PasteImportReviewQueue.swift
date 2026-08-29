import Foundation

/// Serialisiert den Start der Paste-Import-Editor-Warteschlange nach Sheet-/Alert-Dismiss.
///
/// Zwei Aufrufe vor dem ersten `present` (z. B. Fehler-OK und Sheet-Dismiss) würden sonst
/// nach `Task.yield` zwei Kandidaten gleichzeitig öffnen.
@MainActor
public final class PasteImportReviewQueue {
    private var isAdvancing = false

    public init() {}

    /// Plant genau eine Präsentation, sobald `hasPending` wahr ist und kein Lauf offen ist.
    @discardableResult
    public func advance(
        ifPending hasPending: Bool,
        present: @escaping @MainActor () -> Void
    ) -> Task<Void, Never>? {
        guard hasPending, !isAdvancing else { return nil }
        isAdvancing = true
        return Task {
            defer { isAdvancing = false }
            await Task.yield()
            present()
        }
    }
}
