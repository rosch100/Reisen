import SwiftUI
import ReisenData
import ReisenDomain

/// SSOT: Offen-Liste mit Fill-Section + Rest (iOS/macOS).
public struct OpenBookingsFillSections<Row: View>: View {
    let partition: OpenBookingFillPartition
    let row: (SDBooking, String?) -> Row

    public init(
        partition: OpenBookingFillPartition,
        @ViewBuilder row: @escaping (SDBooking, String?) -> Row
    ) {
        self.partition = partition
        self.row = row
    }

    public var body: some View {
        if partition.fillable.isEmpty {
            otherRows
        } else {
            Section {
                ForEach(partition.fillable, id: \.booking.id) { item in
                    row(item.booking, L10n.tripCompletenessFillCaption(tripTitle: item.trip.title))
                }
            } header: {
                Text(L10n.string(.tripCompletenessOpenSection))
            } footer: {
                Text(L10n.string(.tripCompletenessOpenSectionFooter))
            }

            if !partition.other.isEmpty {
                Section(L10n.string(.tripCompletenessOpenOtherSection)) {
                    otherRows
                }
            }
        }
    }

    @ViewBuilder
    private var otherRows: some View {
        ForEach(partition.other, id: \.id) { booking in
            row(booking, nil)
        }
    }
}
