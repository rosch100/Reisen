import SwiftUI
import ReisenData
import ReisenDomain

/// iOS Trip-Übersicht: Completeness als Label-Zeile (nicht tappable).
public struct TripCompletenessOverviewRow: View {
    let completeness: TripCompleteness

    public init(completeness: TripCompleteness) {
        self.completeness = completeness
    }

    public var body: some View {
        if completeness.hasBookings {
            let captions = L10n.tripCompletenessCaptionParts(completeness)
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text(title)
                        .font(.body)
                } icon: {
                    Image(systemName: iconName)
                }
                .foregroundStyle(.primary)

                if let kindCaption = captions.kind {
                    Text(kindCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let edgeCaption = captions.edge {
                    Text(edgeCaption)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if let unknownCaption = captions.unknown {
                    Text(unknownCaption)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L10n.tripCompletenessAccessibility(completeness))
        }
    }

    private var title: String {
        if completeness.hasTimeGaps {
            return L10n.tripCompletenessGapCount(completeness.interBookingGapCount)
        }
        return L10n.string(.tripCompletenessNone)
    }

    private var iconName: String {
        completeness.hasTimeGaps ? "arrow.left.arrow.right" : "checkmark.circle"
    }
}

/// Trailing Count in der Reisen-Liste (nur wenn Badge angezeigt werden soll).
public struct TripCompletenessListAccessory: View {
    let gapCount: Int

    public init(gapCount: Int) {
        self.gapCount = gapCount
    }

    public var body: some View {
        Text("\(gapCount)")
            .font(.body.monospacedDigit())
            .foregroundStyle(.secondary)
            .accessibilityLabel(L10n.tripCompletenessGapCount(gapCount))
    }
}

/// Tertiäre Completeness-Details unter macOS Overview-Facts.
public struct TripCompletenessMacDetailCaption: View {
    let completeness: TripCompleteness

    public init(completeness: TripCompleteness) {
        self.completeness = completeness
    }

    public var body: some View {
        if let text = L10n.tripCompletenessJoinedDetailCaption(completeness) {
            Text(text)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
    }
}
