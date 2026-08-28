import SwiftUI
import ReisenDomain

/// Untere Statuszeile mit letztem Sync — gleiche Chrom auf Reise- und Offene-Buchungs-Details.
public struct BookingLastSyncedBar: View {
    public static var barHeight: CGFloat { 32 }

    let synced: Date

    public init(synced: Date) {
        self.synced = synced
    }

    private var syncedText: String {
        synced.formatted(date: .abbreviated, time: .shortened)
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(L10n.string(.tripLastSynced))
                .font(.caption2)
                .foregroundStyle(.secondary)

            CopyableFieldValue(
                value: syncedText,
                textStyle: .caption2,
                foregroundStyle: .secondary,
                lineLimit: 1
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .background(.bar)
    }
}
