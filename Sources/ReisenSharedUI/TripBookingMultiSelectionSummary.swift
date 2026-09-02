import SwiftUI
import ReisenDomain

/// Summary for multiple selected trip-timeline bookings (macOS detail).
public struct TripBookingMultiSelectionSummary: View {
    let selectedCount: Int
    var onRemoveFromTrip: (() -> Void)?

    public init(
        selectedCount: Int,
        onRemoveFromTrip: (() -> Void)? = nil
    ) {
        self.selectedCount = selectedCount
        self.onRemoveFromTrip = onRemoveFromTrip
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.format(.tripSelectedTimelineBookings, selectedCount))
                .font(.headline)

            if let onRemoveFromTrip {
                Button(role: .destructive, action: onRemoveFromTrip) {
                    Text(L10n.string(.actionRemoveFromTrip))
                }
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .accessibilityIdentifier(UITestingIdentifiers.inspector)
    }
}
