import SwiftUI
import ReisenDomain

/// Summary for multiple selected trip-timeline bookings (macOS detail).
public struct TripBookingMultiSelectionSummary: View {
    let selectedCount: Int
    var onRemoveFromTrip: (() -> Void)?
    var onDelete: (() -> Void)?

    public init(
        selectedCount: Int,
        onRemoveFromTrip: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.selectedCount = selectedCount
        self.onRemoveFromTrip = onRemoveFromTrip
        self.onDelete = onDelete
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

            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Text(L10n.string(.actionDeleteEllipsis))
                }
                .controlSize(.large)
                .accessibilityIdentifier(UITestingIdentifiers.deleteBookingMenu)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .accessibilityIdentifier(UITestingIdentifiers.tripBookingMultiSelectionSummary)
    }
}
