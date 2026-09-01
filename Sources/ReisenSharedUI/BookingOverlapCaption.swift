import SwiftUI
import ReisenDomain

/// SSOT: Overlap-Caption (Sichtbarkeit, L10n-Text, Symbol + A11y) für macOS/iOS.
public struct BookingOverlapCaption: View {
    public let partnerTitles: [String]

    public init(partnerTitles: [String]) {
        self.partnerTitles = partnerTitles
    }

    /// Partner-Titel in Partner-Reihenfolge; fehlende Titel werden übersprungen.
    nonisolated public static func partnerTitles(
        for bookingID: UUID,
        partnerIDsByBookingID: [UUID: [UUID]],
        titleByID: [UUID: String]
    ) -> [String] {
        (partnerIDsByBookingID[bookingID] ?? []).compactMap { titleByID[$0] }
    }

    /// Caption nur wenn mindestens ein Partner-Titel vorliegt.
    nonisolated public static func isVisible(partnerTitles: [String]) -> Bool {
        !partnerTitles.isEmpty
    }

    /// Identisch mit `L10n.overlapLabel(partnerTitles:)`.
    nonisolated public static func labelText(partnerTitles: [String]) -> String {
        L10n.overlapLabel(partnerTitles: partnerTitles)
    }

    nonisolated public static func helpText(partnerTitles: [String]) -> String {
        L10n.overlapHelp(partnerTitles: partnerTitles)
    }

    public var body: some View {
        let text = Self.labelText(partnerTitles: partnerTitles)
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
        .help(Self.helpText(partnerTitles: partnerTitles))
        .accessibilityLabel(text)
    }
}
