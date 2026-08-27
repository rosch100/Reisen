import SwiftUI
import ReisenDomain

/// Untere Statuszeile mit letztem Sync — gleiche Chrom auf Reise- und Offene-Buchungs-Details.
public struct BookingLastSyncedBar: View {
    public static var barHeight: CGFloat { 32 }

    let synced: Date

    public init(synced: Date) {
        self.synced = synced
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(L10n.string(.tripLastSynced))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(synced.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .background(.bar)
    }
}
