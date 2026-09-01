import SwiftUI
import ReisenDomain

/// SSOT: Overlap-Caption (Sichtbarkeit, L10n-Text, Symbol + A11y) für macOS/iOS.
public struct BookingOverlapCaption: View {
    public let extraCount: Int

    public init(extraCount: Int) {
        self.extraCount = extraCount
    }

    /// Caption nur bei Overlap-Count > 0.
    nonisolated public static func isVisible(overlapCount: Int) -> Bool {
        overlapCount > 0
    }

    /// Identisch mit `L10n.overlapLabel(extraCount:)`.
    nonisolated public static func labelText(extraCount: Int) -> String {
        L10n.overlapLabel(extraCount: extraCount)
    }

    public var body: some View {
        let text = Self.labelText(extraCount: extraCount)
        Label {
            Text(text)
                .font(.caption)
                .foregroundStyle(.orange)
        } icon: {
            Image(systemName: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        .labelStyle(.titleAndIcon)
        .accessibilityLabel(text)
    }
}
