import Foundation

/// Detects portal cancel completion pages for post-sheet provider resync.
public enum PortalCancelCompletionDetector: Sendable {
    /// Opodo v1 text marker (same semantics as `OpodoCancelAssistScript`).
    public static let opodoAlreadyCancelledPattern = #"bereits\s+storniert"#

    public static func needsPageTextProbe(provider: ProviderID) -> Bool {
        provider == .opodo
    }

    public static func looksCompleted(
        provider: ProviderID,
        url: URL?,
        pageText: String?
    ) -> Bool {
        _ = url
        switch provider {
        case .opodo:
            guard let pageText, !pageText.isEmpty else { return false }
            return pageText.range(
                of: opodoAlreadyCancelledPattern,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
        default:
            return false
        }
    }
}
